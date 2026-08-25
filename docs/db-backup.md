# 本番 DB のバックアップとリストア

本番 Neon DB の日次バックアップと、そこからの復旧手順。

## なぜ持っているか

Neon の Free プランは Point-in-Time Restore の保持期間が **6 時間**しかない。誤操作や不正なマイグレーションを翌日以降に見つけた場合、Neon の機能だけでは戻せない。そのため **Neon とは独立したダンプ**を S3 に置いている。

## 仕組み

| | |
|---|---|
| 実行 | GitHub Actions `Backup DB Prod`（毎日 18:10 UTC = JST 03:10 / 手動実行も可） |
| 取得方法 | `pg_dump --format=custom`（サーバーに合わせて `postgres:18` コンテナで実行） |
| 保存先 | `s3://rikako-db-backups-production/production/YYYY/MM/DD/rikako-<timestamp>.dump` |
| 暗号化 | S3 サーバーサイド暗号化（AES256） |
| 保持 | 30 日で自動削除（S3 Lifecycle） |
| 権限 | OIDC の `rikako-production-github-actions`。**書き込みのみ**で、読み出し権限は持たせていない |
| 失敗時 | Slack（`/rikako/production/slack-alert-webhook-url`）へ通知 |

接続文字列は SSM SecureString `/rikako/production/database-url` から取得し、**GitHub Actions のログに出さない**（`::add-mask::` でマスクし、コマンドライン引数にも渡さない）。このリポジトリは public のため必須。

### 接続先が pooler ではない理由

SSM の `database-url` には Neon の**直接エンドポイント**が入っている。アプリ（公開 API / 管理 API）は起動時に `DB_USE_POOLER=true` を見て `dbconn.Pooled()` でホストを pooler へ変換して使うが、**バックアップでは変換しない**。

`pg_dump` は PgBouncer の transaction pooling と相性が悪く、セッションをまたぐ操作で失敗しやすいため。SSM の値をそのまま使えばよい。

## バックアップの確認

```bash
export AWS_PROFILE=<prod のプロファイル>   # docs/aws-setup.md 参照

# 直近のバックアップ一覧
aws s3 ls s3://rikako-db-backups-production/production/ --recursive | tail -10
```

## リストア手順

**本番へ直接戻す前に、必ず別のデータベースへ復元して中身を確認すること。**

### 1. ダンプを取得する

```bash
export AWS_PROFILE=<prod のプロファイル>
aws s3 cp s3://rikako-db-backups-production/production/2026/08/25/rikako-20260825T181000Z.dump ./restore.dump
```

### 2. 検証用のデータベースへ復元する

ローカルの PostgreSQL 18 に復元して内容を確認する。

**復元先のデータベースは事前に作る必要がある。** `pg_restore --dbname` は既存のデータベースへ接続するため、無い状態では接続に失敗する。

```bash
docker compose up -d   # ローカルの postgres:18

# 検証用データベースを作る（既にあれば作り直す）
docker run --rm --network host postgres:18 \
  psql "postgres://rikako:password@host.docker.internal:5432/postgres" \
    -c 'DROP DATABASE IF EXISTS rikako_restore_check' \
    -c 'CREATE DATABASE rikako_restore_check'

docker run --rm -v "$PWD:/backup" --network host postgres:18 \
  pg_restore --dbname "postgres://rikako:password@host.docker.internal:5432/rikako_restore_check" \
    --no-owner --no-privileges /backup/restore.dump
```

作ったばかりの空のデータベースへ入れるので `--clean --if-exists` は不要。

行数や最新の更新時刻を見て、期待する時点のデータかを確認する。

```sql
SELECT count(*) FROM users;
SELECT count(*) FROM user_answers;
SELECT max(created_at) FROM user_answers;
```

### 3. 本番へ戻す

**`pg_restore --clean` で今の DB を上書きする方法は使わない。**

`--clean` が削除するのは**アーカイブに含まれるオブジェクトだけ**で、バックアップ取得後のマイグレーションが追加したテーブル・制約・関数などは古いダンプに存在しないため削除されずに残る。「不正なマイグレーションを翌日以降に見つけて戻す」という本来の用途では、**新旧スキーマが混ざった状態**になり「バックアップ時点へ戻った」とは言えない。

代わりに、**空の新しい DB へ復元してから接続先を切り替える**。元の DB を壊さないので、問題があれば戻せる。

#### 3-1. 利用者へ告知する（これだけでは書き込みは止まらない）

`app_status.is_maintenance` を立てると、iOS アプリは起動時にメンテナンス画面へ切り替わる。

```bash
curl -u 'ユーザー名:パスワード' -X PUT https://admin.rikako.org/api/app-status \
  -H 'Content-Type: application/json' \
  -d '{"isMaintenance": true, "maintenanceMessage": "データ復旧作業中です"}'
```

**このフラグは告知用であって、書き込みを拒否する仕組みではない。** API のハンドラは通常どおり動くため、以下からは書き込めてしまう。

- 既に起動していて `/status` を再取得していない iOS アプリ
- Web（`it.rikako.org`）
- API の直接呼び出し
- 管理 API

そのため、次の 3-2 で**技術的に止める**。

#### 3-2. API を止めて書き込みを遮断する

公開 API と管理 API はどちらも Lambda なので、**予約同時実行を 0 にすると新規の実行が止まる**。

```bash
for FN in rikako-api-production rikako-admin-api-production; do
  aws lambda put-function-concurrency \
    --function-name "$FN" --reserved-concurrent-executions 0
done
```

**実行中のリクエストが終わるまで少し待つ**（数十秒）。止まったことを確認する。

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/status   # 502/503
```

> **途中で中断する場合も、必ず 3-8 の復帰手順を実行すること。** 予約同時実行 0 のまま放置すると API は停止したままになる。

#### 3-3. 復元先の空 DB を用意する

Neon のコンソール（または API）で、**本番プロジェクトに新しいブランチ**を作る（例: `restore-20260825`）。ブランチなら既存の本番ブランチに触れずに済み、切り戻しも容易。

作成後、そのブランチの接続文字列（**直接エンドポイント**）を控える。

`BRANCH_URL` はブランチの既定 DB（管理操作用）、`RESTORE_DB_URL` はこれから作る復元先の DB。**ホストは同じで、データベース名だけが違う。**

```bash
BRANCH_URL='postgres://USER:PASS@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require'
RESTORE_DB_URL='postgres://USER:PASS@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb_restore?sslmode=require'
```

> 新しいブランチは作成元の時点のデータを含む。**ダンプを入れる前に、専用の空データベースを作る**こと。

```bash
docker run --rm -e BRANCH_URL postgres:18 \
  sh -c 'psql "$BRANCH_URL" -c "DROP DATABASE IF EXISTS neondb_restore" \
                            -c "CREATE DATABASE neondb_restore"'
```

#### 3-4. ダンプを復元する

**`--exit-on-error` を付ける。** 付けないとエラーがあっても最後まで進み、欠けたまま「成功」して見える。

```bash
docker run --rm -e RESTORE_DB_URL -v "$PWD:/backup" postgres:18 \
  sh -c 'pg_restore --dbname "$RESTORE_DB_URL" --exit-on-error --no-owner --no-privileges /backup/restore.dump'
```

#### 3-5. 復元先を直接確認する

API はまだ止めたままなので、**復元先の DB に直接つないで**確認する。

```sql
SELECT count(*) FROM users;
SELECT count(*) FROM accounts;
SELECT count(*) FROM user_answers;

-- マイグレーションの版が期待どおりか（不正なマイグレーションを戻す場合は特に重要）
SELECT * FROM schema_migrations;

-- account_id が指す accounts が存在するか
SELECT count(*) FROM users u LEFT JOIN accounts a ON a.id = u.account_id
WHERE u.account_id IS NOT NULL AND a.id IS NULL;
```

#### 3-6. アプリコードとの互換性を確認する

**古いバックアップへ戻すと `schema_migrations` も過去へ戻る。** 障害の原因が「マイグレーションと同時にリリースしたコード」だった場合、**現在の Lambda コードのまま再開すると、存在しない列やテーブルを参照して再び落ちる**。

3-5 で確認した `schema_migrations` の版に対して、いま動いているコードが動作するかを判断する。合わない場合は、**Lambda のイメージも当時のものへ戻してから**再開する。

```bash
# いま Lambda が使っているイメージ（digest 付き）
aws lambda get-function --function-name rikako-api-production \
  --query 'Code.ImageUri' --output text
```

デプロイは `:production` という**動くタグ**を上書きする方式なので、過去のイメージはタグでは辿れない。**digest で指定する**。

```bash
# ECR は shared アカウント。push 日時の新しい順に並べる
AWS_PROFILE=<shared のプロファイル> aws ecr describe-images \
  --repository-name rikako-api --region ap-northeast-1 \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[:5].[imageDigest,imagePushedAt,imageTags]' \
  --output table
```

戻す場合（**concurrency を解除する前に行う**）。

```bash
REG=579039992557.dkr.ecr.ap-northeast-1.amazonaws.com
aws lambda update-function-code --function-name rikako-api-production \
  --image-uri "$REG/rikako-api@sha256:<digest>"
aws lambda wait function-updated --function-name rikako-api-production
```

管理 API（`rikako-admin-api-production` / `rikako-admin-api`）も同様に判断する。

> コードを戻した場合、**復旧後に main の内容と食い違ったままになる**。落ち着いたらリバートやマイグレーションのやり直しを含めて、コード側の整合も取ること。

#### 3-7. 接続先を切り替える

**切り替える前に、現在の値を必ず控える**（切り戻し用）。

```bash
# 現在の値を退避（画面に出さない）
aws ssm get-parameter --name /rikako/production/database-url --with-decryption \
  --query 'Parameter.Value' --output text > ./previous-database-url.txt
chmod 600 ./previous-database-url.txt

aws ssm put-parameter --name /rikako/production/database-url \
  --type SecureString --overwrite --value "$RESTORE_DB_URL"
```

> このパラメータは Terraform で `lifecycle.ignore_changes = [value]` になっているため、**手動で上書きしても次の apply で巻き戻らない**（[運用ランブックのローテ手順](runbook.md#neon-db)と同じ扱い）。

#### 3-8. Lambda を再開する

**SSM を書き換えただけでは切り替わらない。** Lambda は起動時に SSM を解決し、warm な実行環境は古い接続を持ち続けるため、**実行環境を作り直す**必要がある。ローテ手順と同じく `--description` を更新する。

```bash
TS=$(date +%s)
for FN in rikako-api-production rikako-admin-api-production; do
  aws lambda update-function-configuration --function-name "$FN" \
    --description "db restore $TS" > /dev/null
  aws lambda wait function-updated --function-name "$FN"
  # 予約同時実行の設定を削除して再開（元は予約なし）
  aws lambda delete-function-concurrency --function-name "$FN"
done
```

疎通を確認する。

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/status      # 200
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/workbooks   # 200（DB を叩く）
```

#### 3-9. メンテナンスを解除する

**復元した DB の `app_status` はダンプ時点の値**（通常は `is_maintenance = false`）。確認し、必要なら明示的に戻す。

```bash
curl -s https://api.rikako.org/status   # isMaintenance を確認

curl -u 'ユーザー名:パスワード' -X PUT https://admin.rikako.org/api/app-status \
  -H 'Content-Type: application/json' \
  -d '{"isMaintenance": false, "maintenanceMessage": ""}'
```

ログイン済みのアカウントで学習記録が見えることも確認する。

#### 3-10. 問題があれば切り戻す

元の DB は触っていないので、SSM を戻せば元に戻る。ただし **切り替えのときと同じく、先に書き込みを止めること。**

止めずに戻すと、Lambda 2本の設定更新が終わるまでの間、**あるリクエストは復旧 DB へ、別のリクエストは旧 DB へ書き込む**（split-brain）。どちらにも欠けたデータが残り、あとから突き合わせるのは難しい。

```bash
# 1. 書き込みを止める
for FN in rikako-api-production rikako-admin-api-production; do
  aws lambda put-function-concurrency \
    --function-name "$FN" --reserved-concurrent-executions 0
done

# 2. 実行中のリクエストが終わるまで待つ（数十秒）
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/status   # 502/503

# 3. SSM を旧 URL へ戻す
aws ssm put-parameter --name /rikako/production/database-url \
  --type SecureString --overwrite --value "$(cat ./previous-database-url.txt)"

# 4. 実行環境を作り直す（SSM の書き換えだけでは切り替わらない）
TS=$(date +%s)
for FN in rikako-api-production rikako-admin-api-production; do
  aws lambda update-function-configuration --function-name "$FN" \
    --description "db rollback $TS" > /dev/null
  aws lambda wait function-updated --function-name "$FN"
done

# 5. 再開する
for FN in rikako-api-production rikako-admin-api-production; do
  aws lambda delete-function-concurrency --function-name "$FN"
done

# 6. 接続先と主要データを確認する
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/workbooks   # 200
```

3-6 で Lambda のイメージも戻していた場合は、**それも元へ戻す**こと。

落ち着いたら `previous-database-url.txt` を削除し、Terraform 側（`neon_project` のブランチ構成）も実態に合わせるか検討する。

## 注意点

- **今の DB を `pg_restore --clean` で上書きする方法は使わない。** `--clean` が削除するのはアーカイブに含まれるオブジェクトだけで、バックアップ取得後のマイグレーションが追加したものは残る。新旧スキーマが混ざるため「その時点へ戻った」とは言えない
- 部分的に戻したい場合（特定テーブルだけなど）は、新しい DB へ復元したうえで必要な範囲を移す
- ダンプは `pg_dump` 実行時点のスナップショット。**それ以降の書き込みは失われる**
- 保持は 30 日。それより前へ戻す必要がある要件が出たら、保持期間か保存先を見直す
- dev のバックアップは取得していない（本番のみ）
- **失敗通知は「ワークフローが動いて失敗した」ときしか出ない。** スケジュール自体が遅延・停止した場合は無通知になる。public リポジトリでは 60 日間アクティビティが無いとスケジュールが自動で無効化される点にも注意（最新バックアップの鮮度監視は別途検討）
