# Rikako

問題集アプリ

## セットアップ

### 環境変数設定（初回のみ）

```bash
cp .env.example .env
```

必要に応じて `.env` の内容を編集してください。

### 起動

```bash
# PostgreSQL + APIサーバーを起動
docker compose up -d

# PostgreSQLのみ起動（APIはローカルで実行）
docker compose up -d postgres
```

### 停止

```bash
docker compose down
```

## DB接続

```bash
# ローカルから
psql -h localhost -U rikako -d rikako
# パスワード: password

# Docker経由
docker exec -it rikako-postgres psql -U rikako -d rikako
```

### 接続情報

| 項目 | 値 |
|-----|-----|
| Host | localhost |
| Port | 5432 |
| User | rikako |
| Password | password |
| Database | rikako |

## マイグレーション

```bash
# 適用
docker run --rm -v $(pwd)/migrations:/migrations \
  migrate/migrate -path=/migrations \
  -database "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" up

# ロールバック (1つ戻す)
docker run --rm -v $(pwd)/migrations:/migrations \
  migrate/migrate -path=/migrations \
  -database "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" down 1

# バージョン確認
docker run --rm -v $(pwd)/migrations:/migrations \
  migrate/migrate -path=/migrations \
  -database "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" version
```

### PostgreSQL コマンド早見表

| MySQL | PostgreSQL |
|-------|------------|
| SHOW DATABASES; | \l |
| USE db; | \c db |
| SHOW TABLES; | \dt |
| DESCRIBE table; | \d table |

## データインポート

YAMLファイルからDBにデータをインポートします。

```bash
cd app
go run ./cmd/importer -data ../data
```

インポート内容：
- 問題データ（3000問）
- 画像（121枚）
- 問題集（4件）

## APIサーバー

### サーバー起動（Docker）

```bash
# PostgreSQL + APIサーバーを起動
docker compose up -d

# ログ確認
docker compose logs -f api
```

### サーバー起動（ローカル）

```bash
# 環境変数ファイルをコピー（初回のみ）
cp .env.example .env

# サーバー起動
cd app
go run ./cmd/server
```

サーバーは `http://localhost:8080` で起動します。

### エンドポイント

| パス | 説明 |
|------|------|
| `GET /` | ルート |
| `GET /health` | ヘルスチェック |
| `GET /questions` | 問題一覧 |
| `GET /questions/{id}` | 問題詳細 |
| `GET /workbooks` | 問題集一覧 |
| `GET /workbooks/{id}` | 問題集詳細 |

API仕様: https://takoikatakotako.github.io/rikako/api/

## スキーマドキュメント生成

```bash
docker run --rm \
  -v $(pwd):/work \
  -w /work \
  ghcr.io/k1low/tbls:v1.92.3 \
  doc "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" /work/docs/schema
```

生成されたドキュメントは `docs/schema/` に出力されます。

## AWSデプロイ

### アーキテクチャ

- **コンピュート**: AWS Lambda (コンテナイメージ) + Lambda Web Adapter 0.9.1
- **データベース**: Neon PostgreSQL (Serverless)
- **公開API**: API Gateway HTTP API
- **管理API**: CloudFront + Basic Auth → Lambda Function URL (AWS_IAM + OAC)
- **画像配信 / コンテンツ配信**: S3 + CloudFront (OAC)
- **コンテナレジストリ**: Amazon ECR (shared環境で管理)
- **シークレット管理**: AWS SSM Parameter Store (SecureString)。Lambda 環境変数には `ssm:/path` 形式の参照だけを保存し、アプリ起動時に `app/internal/secrets.Resolve` が実値を取得する
- **アラート通知**: CloudWatch Alarm → SNS → Python Lambda (slack_notifier) → Slack
- **認証**: GitHub Actions OIDC
- **IaC**: Terraform (S3ネイティブロック)
- **CI/CD**: GitHub Actions (tfcmt連携)

### 環境

- **Dev環境** (AWSアカウント: 197865631794)
  - 公開API: https://api.dev.rikako.org/
  - 管理画面: https://admin.dev.rikako.org/
  - Image CDN: https://image.dev.rikako.org/
  - Content CDN: https://content.dev.rikako.org/
- **Prod環境** (AWSアカウント: 211125415945)
  - LP: https://rikako.org/
  - 公開API: https://api.rikako.org/
  - 管理画面: https://admin.rikako.org/
  - Image CDN: https://image.rikako.org/
  - Content CDN: https://content.rikako.org/
- **Shared環境** (AWSアカウント: 579039992557): ECR (`rikako-api`, `rikako-admin-api`)

### 初回セットアップ

#### 1. Terraform State管理用S3バケットの作成

各環境のAWSアカウントにS3バケットを作成します：

```bash
# Shared環境（579039992557）
aws s3api create-bucket \
  --bucket rikako-terraform-state \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

# Dev環境（197865631794）
aws s3api create-bucket \
  --bucket rikako-dev-terraform-state \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
```

各バケットにバージョニング、暗号化、パブリックアクセスブロックを設定してください。

#### 2. Neon API Keyの取得

https://console.neon.tech/app/settings/api-keys でAPIキーを作成します。

#### 3. シークレットを SSM Parameter Store に登録

SecureString として登録します（Terraform apply の前提）：

```bash
# Neon API Key（Terraform Provider が利用）
aws ssm put-parameter --name "/rikako/neon-api-key" \
  --value "$NEON_API_KEY" --type SecureString

# 各環境の OpenAI API Key
aws ssm put-parameter --name "/rikako/development/openai-api-key" \
  --value "$OPENAI_API_KEY_DEV" --type SecureString
aws ssm put-parameter --name "/rikako/production/openai-api-key" \
  --value "$OPENAI_API_KEY_PROD" --type SecureString

# 各環境の Slack Webhook URL（お問い合わせ通知用 / アラート通知用）
aws ssm put-parameter --name "/rikako/development/slack-contact-webhook-url" \
  --value "$SLACK_CONTACT_WEBHOOK_DEV" --type SecureString
aws ssm put-parameter --name "/rikako/development/slack-alert-webhook-url" \
  --value "$SLACK_ALERT_WEBHOOK_DEV" --type SecureString
# prod も同様
```

> `DATABASE_URL` は Terraform が Neon の connection_uri から自動で SecureString として登録するため手動登録は不要。
>
> Lambda 環境変数には `ssm:/rikako/<env>/...` のリテラル参照のみが保存され、アプリ起動時に `app/internal/secrets.Resolve` が実値を取得します（[Issue #199](https://github.com/takoikatakotako/rikako/issues/199)）。

> GitHub SecretsへのAWSキー登録は不要です（OIDC認証を使用）。

#### 4. Shared環境のデプロイ（ECR）

```bash
cd terraform/environments/shared
terraform init
terraform apply
```

#### 5. Dev環境のデプロイ

```bash
cd terraform/environments/dev
AWS_PROFILE=rikako-development-sso terraform init
AWS_PROFILE=rikako-development-sso terraform apply
```

#### 6. Prod環境のデプロイ（手動のみ）

```bash
cd terraform/environments/prod
AWS_PROFILE=rikako-production-sso terraform init
AWS_PROFILE=rikako-production-sso terraform apply
```

> Neon APIキーは SSM Parameter Store から Terraform Provider が自動取得します。Lambda 実行時のシークレットは `app/internal/secrets` パッケージが起動時に SSM から取得します。

### 以降のデプロイ

GitHub ActionsのDeployワークフローを実行するだけでOK:

- **Dev**: `main` ブランチへの push で自動実行（`deploy-api-dev.yml` / `deploy-admin-api-dev.yml`）
- **Prod**: 手動 dispatch のみ（`deploy-api-prod.yml` / `deploy-admin-api-prod.yml`）
- **Terraform**: Dev は main push で `apply-terraform-dev.yml` が自動 apply、Prod はローカルから手動 `terraform apply`

### デプロイフロー

1. ECRにDockerイメージをビルド&プッシュ
2. Lambda関数のコード更新
3. ヘルスチェックで動作確認

### マイグレーション（手動実行）

GitHub Actions経由でマイグレーションを実行:

Actions → Run Database Migration → Run workflow

- **Environment**: `dev` または `prod`
- **Direction**: `up` または `down`
- **Steps**: 空欄（すべて）または数値（ステップ数）

### エンドポイントの確認

```bash
cd terraform/environments/dev
terraform output api_endpoint           # 公開API（API Gateway）
terraform output admin_function_url     # 管理APIの Function URL（CloudFront 経由）
```

### コスト見積もり

#### 開発環境（低トラフィック）
- **Lambda**: AWS Free Tier内（月100万リクエスト無料）
- **Neon**: $20-50/月（Auto-suspendで最適化）
- **ECR**: $1/月未満
- **合計**: 約$20-50/月

### リソースの削除

```bash
# Dev環境の削除
cd terraform/environments/dev
terraform destroy

# Shared環境の削除
cd terraform/environments/shared
terraform destroy

# S3バケットの削除（必要に応じて）
aws s3 rb s3://rikako-dev-terraform-state --force
aws s3 rb s3://rikako-terraform-state --force
```
