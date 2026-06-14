# 運用ランブック

> **前提**: AWS CLI プロファイルの設定が必要です。[AWS CLI セットアップ](aws-setup.md) を参照してください。
>
> 以降のコマンドは事前に `aws sso login` 済みで `AWS_PROFILE` が設定されている前提です。
> ```bash
> # dev環境
> export AWS_PROFILE=rikako-development-sso
> # shared環境（ECR操作時）
> export AWS_PROFILE=rikako-shared-sso
> ```

## 環境情報

| 項目 | dev環境 | prod環境 |
|------|---------|----------|
| Lambda (公開API) | `rikako-api-development` | `rikako-api-production` |
| Lambda (管理API) | `rikako-admin-api-development` | `rikako-admin-api-production` |
| Lambda (Slack 通知) | `rikako-slack-notifier-development` | `rikako-slack-notifier-production` |
| 公開API エンドポイント | `https://api.dev.rikako.org` (API Gateway) | `https://api.rikako.org` (API Gateway) |
| 管理画面 | `https://admin.dev.rikako.org` (Basic Auth) | `https://admin.rikako.org` (Basic Auth) |
| 管理API | `https://admin.dev.rikako.org/api` | `https://admin.rikako.org/api` |
| 画像CDN | `https://image.dev.rikako.org/` | `https://image.rikako.org/` |
| コンテンツCDN | `https://content.dev.rikako.org/` | `https://content.rikako.org/` |
| 画像S3 | `rikako-images-development` | `rikako-images-production` |
| コンテンツS3 | `rikako-content-development` | `rikako-content-production` |
| 管理画面S3 | `rikako-admin-development` | `rikako-admin-production` |
| Neon プロジェクト ID | `muddy-tree-64549662` (ap-southeast-1) | `fragrant-poetry-87067174` (ap-southeast-1) |
| Neon エンドポイント | `ep-raspy-lab-a1wo0g6n` | `ep-misty-unit-aoxkoz1d` |
| ECR (shared) | `579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api` | 同左 |
| CloudWatch Dashboard | `rikako-dev` | `rikako-prod` |
| AWSアカウント | 197865631794 | 211125415945 |
| AWS Profile | `rikako-development-sso` | `rikako-production-sso` |

Shared 環境（ECR を共有）: AWS アカウント `579039992557` / プロファイル `rikako-shared-sso`。

---

## 1. デプロイ手順

### 公開API / 管理API

**Dev**: mainブランチへのマージで自動デプロイ（GitHub Actions）。

```bash
# 手動トリガー（Dev）
gh workflow run "Deploy API Dev" --repo takoikatakotako/rikako --ref main
gh workflow run "Deploy Admin API Dev" --repo takoikatakotako/rikako --ref main

# 状況確認
gh run list --repo takoikatakotako/rikako --limit 5
```

**Prod**: 手動 dispatch のみ（自動デプロイなし）。

```bash
gh workflow run "Deploy API Prod" --repo takoikatakotako/rikako --ref main
gh workflow run "Deploy Admin API Prod" --repo takoikatakotako/rikako --ref main
```

#### デプロイフロー

1. Dockerイメージをビルド（`app/Dockerfile.lambda` / `app/Dockerfile.admin`）
2. ECRにプッシュ（タグ: `dev` / `prod`）
3. `aws lambda update-function-code` で Lambda 関数のイメージを更新
4. `aws lambda wait function-updated` で更新完了まで待機
5. `/health` エンドポイントでヘルスチェック

### 管理画面フロントエンド

mainブランチへのマージで `admin/` 配下に変更がある場合に自動デプロイ。

```bash
# 手動デプロイ
gh workflow run "Deploy Admin Frontend Dev" --repo takoikatakotako/rikako --ref main
```

#### デプロイフロー

1. `npm run build` でビルド
2. S3にsync（静的アセット: 1年キャッシュ、HTML: キャッシュなし）
3. CloudFrontキャッシュを無効化

---

## 2. ロールバック手順

### Lambda API（公開・管理共通）

ECRのイメージタグ `dev` は上書き可能。直前のイメージに戻すには:

```bash
# 直近のイメージダイジェストを確認
aws ecr describe-images \
  --registry-id 579039992557 \
  --repository-name rikako-api \
  --query 'imageDetails | sort_by(@, &imagePushedAt) | [-5:].[imagePushedAt,imageDigest]' \
  --output table

# 特定のダイジェストに戻す（公開API）
aws lambda update-function-code \
  --function-name rikako-api-development \
  --image-uri 579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api@sha256:<digest>

# 管理APIも同様
aws lambda update-function-code \
  --function-name rikako-admin-api-development \
  --image-uri 579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-admin-api@sha256:<digest>
```

> **注意**: ECRのライフサイクルポリシーにより最新5イメージのみ保持。古いイメージは自動削除される。

### 管理画面フロントエンド

gitで前のコミットに戻してデプロイワークフローを再実行する。

```bash
# 直前のコミットでデプロイ
gh workflow run "Deploy Admin Frontend Dev" --repo takoikatakotako/rikako --ref <commit-sha>
```

---

## 2.5 シークレット管理（SSM Parameter Store）

Lambda が読むシークレット（`OPENAI_API_KEY` / `SLACK_WEBHOOK_URL` / `DATABASE_URL` 等）は、Lambda 環境変数には `ssm:/path` 形式の参照のみを保存し、起動時に `app/internal/secrets.Resolve` または slack_notifier の `_resolve_ssm` が実値を取得する仕組み（[Issue #199](https://github.com/takoikatakotako/rikako/issues/199)）。

### 管理対象パラメータ

| パス | 内容 | 登録方法 |
|------|------|----------|
| `/rikako/<env>/openai-api-key` | OpenAI API キー | 手動 `put-parameter` |
| `/rikako/<env>/slack-contact-webhook-url` | お問い合わせ通知用 Slack Webhook | 手動 `put-parameter` |
| `/rikako/<env>/slack-alert-webhook-url` | CloudWatch アラート用 Slack Webhook | 手動 `put-parameter` |
| `/rikako/<env>/database-url` | Neon 接続文字列 | Terraform が `neon_project.default.connection_uri` を**初期値**として SecureString 登録。`lifecycle.ignore_changes = [value]` 指定のため以後の値はローテで上書き可（[ローテ手順](#neon-db)参照） |
| `/rikako/neon-api-key` | Neon API キー（Terraform Provider 用） | 手動 `put-parameter` |

### 初回登録

```bash
# 例: dev に OpenAI API key を登録
AWS_PROFILE=rikako-development-sso aws ssm put-parameter \
  --name /rikako/development/openai-api-key \
  --value 'sk-...' \
  --type SecureString \
  --region ap-northeast-1
```

### ローテーション

SSM 値を `put-parameter --overwrite` で更新すれば、**次回 Lambda cold start で新しい値が反映される**（Lambda 関数の再デプロイ不要）。即時反映が必要な場合は Lambda コンソールから「最新バージョンを発行」または `update-function-code` で warm container を破棄する。

```bash
AWS_PROFILE=rikako-development-sso aws ssm put-parameter \
  --name /rikako/development/openai-api-key \
  --value 'sk-new-value...' \
  --type SecureString \
  --overwrite \
  --region ap-northeast-1
```

### 確認

`aws lambda get-function-configuration --query 'Environment.Variables'` で **シークレット実値が出ず `ssm:/...` リテラルだけが返る**ことを確認する。実値が露出していたら漏洩リスクがあるので即対応。

### Neon DB パスワードのローテーション {#neon-db}

`/rikako/<env>/database-url` の Neon パスワードをローテする手順。

> **重要な前提**
> - Neon の role は DB を所有しているため、`terraform apply -replace=neon_role.default` での drop/recreate は **HTTP 422 `ROLE_OWNS_OBJECTS`** で失敗する。ローテは必ず Neon API の **`reset_password`**（role を残しパスワードのみ再生成）で行う。
> - SSM `database-url` は `lifecycle.ignore_changes = [value]` 指定のため、`put-parameter --overwrite` した値を terraform が巻き戻さない。
> - **環境ごとにアプリが使う role/DB が異なる**ので注意:
>   - **dev**: role `rikako_owner` / DB `rikako`
>   - **prod**: role `neondb_owner` / DB `neondb`（Neon デフォルト）
> - リセット直後から旧パスワードは無効になり、warm Lambda は cold start まで DB 接続に失敗する。

```bash
# 例: dev（prod の場合は PROFILE/PROJECT/BRANCH/ROLE/DB/SSM 名を読み替え）
export AWS_PROFILE=rikako-development-sso
API_KEY=$(aws ssm get-parameter --name /rikako/neon-api-key --with-decryption --query Parameter.Value --output text)
PROJECT_ID=muddy-tree-64549662
BRANCH_ID=br-calm-rice-a1123e1l
ROLE=rikako_owner
DB=rikako
HOST=$(cd terraform/environments/dev && terraform state show neon_project.default | grep 'database_host ' | sed -E 's/.*= "(.*)"/\1/')

# 1. パスワードを reset（新パスワードを取得、出力しない）
NEWPASS=$(curl -s -X POST \
  "https://console.neon.tech/api/v2/projects/${PROJECT_ID}/branches/${BRANCH_ID}/roles/${ROLE}/reset_password" \
  -H "Authorization: Bearer ${API_KEY}" -H "Accept: application/json" | jq -r '.role.password')

# 2. SSM を上書き
aws ssm put-parameter --name /rikako/development/database-url --type SecureString --overwrite \
  --value "postgres://${ROLE}:${NEWPASS}@${HOST}/${DB}?sslmode=require"

# 3. Lambda を cold start（warm container に旧パスが残るため）
TS=$(date +%s)
for fn in rikako-api-development rikako-admin-api-development; do
  aws lambda update-function-configuration --function-name "$fn" --description "db rotation $TS" >/dev/null
  aws lambda wait function-updated --function-name "$fn"
done

# 4. 確認（DB を叩くエンドポイントが 200 を返すこと）
curl -s -o /dev/null -w "%{http_code}\n" https://api.dev.rikako.org/workbooks
```

prod は次のように読み替える: `AWS_PROFILE=rikako-production-sso`、`PROJECT_ID` は `cd terraform/environments/prod && terraform state show neon_project.default` の `id`、`BRANCH_ID` は同 `default_branch_id`、`ROLE=neondb_owner`、`DB=neondb`、SSM 名 `/rikako/production/database-url`、関数は `rikako-api-production` / `rikako-admin-api-production`。

---

## 3. マイグレーション実行手順

GitHub Actions のワークフローで実行する。

```bash
# GitHub上で手動実行（推奨）
gh workflow run "Run Database Migration" \
  --repo takoikatakotako/rikako \
  -f environment=dev \
  -f direction=up \
  -f steps=all
```

### パラメータ

| パラメータ | 説明 |
|-----------|------|
| environment | `dev` または `prod` |
| direction | `up`（適用）または `down`（ロールバック） |
| steps | `all`（全て）または数値（ステップ数） |

### マイグレーションロールバック

```bash
# 1ステップ戻す
gh workflow run "Run Database Migration" \
  --repo takoikatakotako/rikako \
  -f environment=dev \
  -f direction=down \
  -f steps=1
```

### ローカルでのマイグレーション

```bash
docker compose up -d postgres

docker run --rm -v $(pwd)/migrations:/migrations \
  migrate/migrate -path=/migrations \
  -database "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" up
```

---

## 4. データインポート・同期手順

### datasync（推奨）

YAMLデータを正としてDBと差分同期する。

```bash
cd app

# ローカルDB
go run ./cmd/datasync -data ../data plan     # 差分確認
go run ./cmd/datasync -data ../data apply    # 反映

# dev環境
go run ./cmd/datasync -data ../data -env dev plan
go run ./cmd/datasync -data ../data -env dev apply
```

詳細は [データ同期 (datasync)](datasync.md) を参照。

### 画像のS3アップロード

```bash
# アップロード
aws s3 sync data/images/ s3://rikako-images-development/ --exclude ".DS_Store"

# 確認
aws s3 ls s3://rikako-images-development/ | wc -l
```

### importer（全件再投入）

全データを削除して再投入する場合に使用。

```bash
cd app && go run ./cmd/importer -data ../data
```

---

## 5. 障害対応フロー

### Lambda障害

**症状**: APIがエラーを返す、タイムアウトする

```bash
# 1. ヘルスチェック（prod は api.rikako.org に置き換え）
curl -s https://api.dev.rikako.org/health

# 2. CloudWatchダッシュボードを確認
# https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards/dashboard/rikako-dev

# 3. Lambda最新ログを確認
aws logs tail /aws/lambda/rikako-api-development --since 30m

# 4. エラーのみ抽出
aws logs filter-log-events \
  --log-group-name /aws/lambda/rikako-api-development \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern "ERROR"

# 5. 必要に応じてロールバック（→ 2. ロールバック手順）
```

### p99 レイテンシアラーム（`public-api-p99-latency`）

**症状**: 「Public API Lambda の p99 レイテンシ（AIチャットを除く）が 10 秒を超えた」という SNS/Slack 通知

- このアラームは Lambda の `Duration` ではなく、アプリが EMF で出力するカスタムメトリクス `Rikako/PublicAPI` / `RequestLatency`（ディメンション `Service=public-api`）の p99 を見ている。
- **AI チャット（`POST /questions/:questionId/chat`）は OpenAI を同期呼び出しするため遅く、このメトリクスから除外済み**（`app/internal/logging/metrics.go`）。チャットだけが遅い場合はこのアラームは鳴らない。
- 鳴った場合はチャット以外の経路が遅い＝本当の遅延劣化。DB スロークエリ・Neon の CU 不足・コールドスタート増を疑う。

```bash
# 遅いリクエストをログから特定（latency でソート）
aws logs filter-log-events \
  --log-group-name /aws/lambda/rikako-api-development \
  --start-time $(date -v-15M +%s000) \
  --filter-pattern '{ $.latency = "*s" }'
```

### DB障害（Neon）

**症状**: API が 500 エラー、`connection refused`

```bash
# 1. Neonダッシュボードを確認
# https://console.neon.tech/

# 2. 接続テスト
go run ./cmd/datasync -data ../data -env dev plan

# 3. Neonのステータスページを確認
# https://neonstatus.com/
```

**Neonが応答しない場合**:
- Neonのステータスページでリージョン障害を確認
- 障害が長引く場合はNeonサポートに連絡

### 画像配信障害

**症状**: 画像が表示されない、403/404エラー

```bash
# 1. CloudFront経由でアクセス確認（prod は image.rikako.org に置き換え）
curl -I https://image.dev.rikako.org/1.png

# 2. S3直接確認
aws s3 ls s3://rikako-images-development/1.png

# 3. CloudFrontキャッシュが古い場合は無効化
aws cloudfront create-invalidation \
  --distribution-id E1LVBAGQ7YS8CR \
  --paths "/*"
```

---

## 6. ログ調査手順

### CloudWatch Logs

```bash
# 直近30分のログ（公開API）
aws logs tail /aws/lambda/rikako-api-development --since 30m --follow

# 直近30分のログ（管理API）
aws logs tail /aws/lambda/rikako-admin-api-development --since 30m --follow

# 特定パターンで検索
aws logs filter-log-events \
  --log-group-name /aws/lambda/rikako-api-development \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern "ERROR"

# 特定リクエストの調査（パスで絞り込み）
aws logs filter-log-events \
  --log-group-name /aws/lambda/rikako-api-development \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern "/questions"
```

### CloudWatch Dashboard

ブラウザで確認:
`https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards/dashboard/rikako-dev`

確認できるメトリクス:
- Invocations（呼び出し回数）
- Duration（平均・p99レイテンシ）
- Errors（エラー数）
- Throttles（スロットリング数）
- ConcurrentExecutions（同時実行数）

> **注意**: ログ保持期間は7日間。それ以前のログは自動削除される。

---

## 7. スケーリング手順

### Neon CU（コンピューティングユニット）変更

現在: dev は 0.25〜2 CU、prod は 0.25〜4 CU（auto-scaling、auto-suspend 無効）。

```bash
cd terraform/environments/dev   # prod は environments/prod

# terraform で変更（neon.tf の default_endpoint_settings を編集）
terraform plan
terraform apply
```

`neon.tf` の該当箇所（`neon_project` の `default_endpoint_settings` ブロック）:

```hcl
resource "neon_project" "default" {
  # ...
  default_endpoint_settings {
    autoscaling_limit_min_cu = 0.25  # 最小CU
    autoscaling_limit_max_cu = 2     # 最大CU（prod は 4）
    suspend_timeout_seconds  = 0     # 常時稼働（auto-suspend 無効）
  }
}
```

### Lambda設定変更

メモリ・タイムアウトの変更は `terraform/environments/dev/main.tf` を編集:

```hcl
module "lambda" {
  memory_size = 512   # MB（現在値）
  timeout     = 30    # 秒（現在値）
}
```

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

### Lambda同時実行数の制限

現在は制限なし（AWSアカウントデフォルト: 1000）。制限が必要な場合:

```bash
# 一時的に制限（Terraform外）
aws lambda put-function-concurrency \
  --function-name rikako-api-development \
  --reserved-concurrent-executions 100

# 制限解除
aws lambda delete-function-concurrency \
  --function-name rikako-api-development
```

---

## 8. Terraform操作

```bash
# Plan/Apply（dev）
cd terraform/environments/dev
terraform plan
terraform apply

# Plan/Apply（shared）
cd terraform/environments/shared
terraform plan
terraform apply
```

> **注意**: PRで `terraform/` 配下を変更するとGitHub Actionsで自動的にplanが実行され、結果がPRにコメントされる。

---

## 9. よくある操作

### 新しい問題を追加する

1. `data/questions/{id}.yml` を作成
2. 必要なら `data/images/{id}.png` を追加
3. `data/workbooks/*.yml` の `questions` に追加
4. `datasync plan` で確認 → `datasync apply` で反映
5. 画像があれば `aws s3 sync` でS3にアップロード

### Cognito ユーザー作成

```bash
aws cognito-idp admin-create-user \
  --user-pool-id ap-northeast-1_DvsZzCoJw \
  --username <email> \
  --user-attributes Name=email,Value=<email>
```

### CloudFrontキャッシュクリア

```bash
# 画像CDN
aws cloudfront create-invalidation \
  --distribution-id E1LVBAGQ7YS8CR \
  --paths "/*"

# 管理画面
aws cloudfront create-invalidation \
  --distribution-id EIA13UUJ41NKO \
  --paths "/*"
```
