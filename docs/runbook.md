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

| 項目 | dev環境 |
|------|---------|
| Lambda (公開API) | `rikako-api-development` |
| Lambda (管理API) | `rikako-admin-api-development` |
| Function URL (公開) | `https://umay5vbvquds44pubogp2jpaky0okiaj.lambda-url.ap-northeast-1.on.aws/` |
| Function URL (管理) | `https://wk45zga7vrkbh5n3wxyol4d4sm0hihvp.lambda-url.ap-northeast-1.on.aws/` |
| 管理画面 | `https://d3j2hmwpzlg763.cloudfront.net` |
| 画像CDN | `https://d1ovm6exq28tn1.cloudfront.net/` |
| 画像S3 | `rikako-images-development` |
| 管理画面S3 | `rikako-admin-development` |
| Neon DB | `rikako-development` (ap-southeast-1) |
| ECR (shared) | `579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api` |
| CloudWatch Dashboard | `rikako-dev` |
| AWSアカウント (dev) | 197865631794 |
| AWSアカウント (shared) | 579039992557 |
| AWS Profile (dev) | [セットアップ参照](aws-setup.md) |
| AWS Profile (shared) | [セットアップ参照](aws-setup.md) |

---

## 1. デプロイ手順

### 公開API / 管理API

mainブランチへのマージで自動デプロイされる（GitHub Actions）。

手動デプロイが必要な場合:

```bash
# GitHub Actions から手動トリガー
gh workflow run "Deploy Dev" --repo takoikatakotako/rikako --ref main
gh workflow run "Deploy Admin API Dev" --repo takoikatakotako/rikako --ref main

# 状況確認
gh run list --repo takoikatakotako/rikako --limit 5
```

#### デプロイフロー

1. Dockerイメージをビルド（`app/Dockerfile.lambda`）
2. ECRにプッシュ（タグ: `dev`）
3. Lambda関数のイメージを更新
4. 更新完了まで待機
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
# 1. ヘルスチェック
curl -s https://umay5vbvquds44pubogp2jpaky0okiaj.lambda-url.ap-northeast-1.on.aws/health

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
# 1. CloudFront経由でアクセス確認
curl -I https://d1ovm6exq28tn1.cloudfront.net/1.png

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

現在: 0.25〜2 CU（auto-scaling）

```bash
cd terraform/environments/dev

# terraform で変更（neon.tf の min/max compute units を編集）
terraform plan
terraform apply
```

`neon.tf` の該当箇所:

```hcl
resource "neon_endpoint" "default" {
  autoscaling_limit_min_cu = 0.25  # 最小CU
  autoscaling_limit_max_cu = 2     # 最大CU
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
