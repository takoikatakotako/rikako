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

**破壊的な操作。アプリを動かしたまま `--clean` すると、復元中の読み書きが失敗するか、中途半端な状態のデータが混ざる。** 必ず書き込みを止めてから行う。

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
# 502/503 になれば新規実行が止まっている
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/status

# 同時実行が 0 に落ちているか
aws cloudwatch get-metric-statistics --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --dimensions Name=FunctionName,Value=rikako-api-production \
  --start-time "$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 60 --statistics Maximum
```

> **途中で中断する場合も、必ず 3-6 の復帰手順を実行すること。** 予約同時実行 0 のまま放置すると API は停止したままになる。

#### 3-3. 現在の状態を別キーで確保する

戻した結果が期待と違ったときのために、**復元前の状態も残す**。`Backup DB Prod` を手動実行するのが早い。

#### 3-4. 復元する

```bash
DATABASE_URL=$(aws ssm get-parameter --name /rikako/production/database-url \
  --with-decryption --query 'Parameter.Value' --output text)

docker run --rm -e DATABASE_URL -v "$PWD:/backup" postgres:18 \
  sh -c 'pg_restore --dbname "$DATABASE_URL" --clean --if-exists --no-owner --no-privileges /backup/restore.dump'
```

#### 3-5. 整合性を確認する

API はまだ止めたままなので、**DB に直接つないで**確認する。

```sql
SELECT count(*) FROM users;
SELECT count(*) FROM accounts;
SELECT count(*) FROM user_answers;
-- account_id が指す accounts が存在するか
SELECT count(*) FROM users u LEFT JOIN accounts a ON a.id = u.account_id
WHERE u.account_id IS NOT NULL AND a.id IS NULL;
```

#### 3-6. API を戻す

予約同時実行の設定を**削除**して、アカウント共通の枠（1000）に戻す。`--reserved-concurrent-executions` に元の値を入れ直すのではなく、**設定自体を消す**のが正しい（もともと予約は設定していないため）。

```bash
for FN in rikako-api-production rikako-admin-api-production; do
  aws lambda delete-function-concurrency --function-name "$FN"
done

# 予約が消えていること（何も返らない）
aws lambda get-function-concurrency --function-name rikako-api-production
```

疎通を確認する。

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://api.rikako.org/status   # 200
```

#### 3-7. メンテナンスを解除する

**`--clean` で復元すると `app_status` もダンプ時点の値に戻る**（通常は `is_maintenance = false`）。解除されているかを確認し、必要なら明示的に戻す。

```bash
curl -s https://api.rikako.org/status   # isMaintenance を確認

curl -u 'ユーザー名:パスワード' -X PUT https://admin.rikako.org/api/app-status \
  -H 'Content-Type: application/json' \
  -d '{"isMaintenance": false, "maintenanceMessage": ""}'
```

ログイン済みのアカウントで学習記録が見えることも確認する。

## 注意点

- **`--clean --if-exists` は既存のオブジェクトを削除してから復元する。** 部分的に戻したい場合は `--table` 等で対象を絞る
- ダンプは `pg_dump` 実行時点のスナップショット。**それ以降の書き込みは失われる**
- 保持は 30 日。それより前へ戻す必要がある要件が出たら、保持期間か保存先を見直す
- dev のバックアップは取得していない（本番のみ）
- **失敗通知は「ワークフローが動いて失敗した」ときしか出ない。** スケジュール自体が遅延・停止した場合は無通知になる。public リポジトリでは 60 日間アクティビティが無いとスケジュールが自動で無効化される点にも注意（最新バックアップの鮮度監視は別途検討）
