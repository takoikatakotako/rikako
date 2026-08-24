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

```bash
docker compose up -d   # ローカルの postgres:18

docker run --rm -v "$PWD:/backup" --network host postgres:18 \
  pg_restore --dbname "postgres://rikako:password@host.docker.internal:5432/rikako_restore_check" \
    --clean --if-exists --no-owner --no-privileges /backup/restore.dump
```

行数や最新の更新時刻を見て、期待する時点のデータかを確認する。

```sql
SELECT count(*) FROM users;
SELECT count(*) FROM user_answers;
SELECT max(created_at) FROM user_answers;
```

### 3. 本番へ戻す

**破壊的な操作。実行前に現在の本番の状態をダンプしておくこと**（`Backup DB Prod` を手動実行するのが早い）。

```bash
# 接続先は SSM から取得する（値は表示しない）
DATABASE_URL=$(aws ssm get-parameter --name /rikako/production/database-url \
  --with-decryption --query 'Parameter.Value' --output text)

docker run --rm -e DATABASE_URL -v "$PWD:/backup" postgres:18 \
  sh -c 'pg_restore --dbname "$DATABASE_URL" --clean --if-exists --no-owner --no-privileges /backup/restore.dump'
```

復元後は、アプリが正常に読み書きできることを確認する。

- `curl https://api.rikako.org/status`
- ログイン済みのアカウントで学習記録が見えること

## 注意点

- **`--clean --if-exists` は既存のオブジェクトを削除してから復元する。** 部分的に戻したい場合は `--table` 等で対象を絞る
- ダンプは `pg_dump` 実行時点のスナップショット。**それ以降の書き込みは失われる**
- 保持は 30 日。それより前へ戻す必要がある要件が出たら、保持期間か保存先を見直す
- dev のバックアップは取得していない（本番のみ）
