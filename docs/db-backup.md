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

#### 3-1. メンテナンスモードに切り替える

`app_status.is_maintenance` を立てると、iOS アプリはメンテナンス画面になる。管理 API から切り替える。

```bash
curl -u 'ユーザー名:パスワード' -X PUT https://admin.rikako.org/api/app-status \
  -H 'Content-Type: application/json' \
  -d '{"isMaintenance": true, "maintenanceMessage": "データ復旧作業中です"}'
```

#### 3-2. 現在の状態を別キーで確保する

戻した結果が期待と違ったときのために、**復元前の状態も残す**。`Backup DB Prod` を手動実行するのが早い。

#### 3-3. 復元する

```bash
DATABASE_URL=$(aws ssm get-parameter --name /rikako/production/database-url \
  --with-decryption --query 'Parameter.Value' --output text)

docker run --rm -e DATABASE_URL -v "$PWD:/backup" postgres:18 \
  sh -c 'pg_restore --dbname "$DATABASE_URL" --clean --if-exists --no-owner --no-privileges /backup/restore.dump'
```

#### 3-4. 整合性を確認する

```bash
curl -s https://api.rikako.org/status
```

主要テーブルの行数と、外部キーが壊れていないことを見る。

```sql
SELECT count(*) FROM users;
SELECT count(*) FROM accounts;
SELECT count(*) FROM user_answers;
-- account_id が指す accounts が存在するか
SELECT count(*) FROM users u LEFT JOIN accounts a ON a.id = u.account_id
WHERE u.account_id IS NOT NULL AND a.id IS NULL;
```

#### 3-5. メンテナンスを解除する

**`--clean` で復元すると `app_status` もダンプ時点の値に戻る**（通常は `is_maintenance = false`）。解除されているかを確認し、必要なら明示的に戻す。

```bash
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
