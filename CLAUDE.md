# CLAUDE.md

このファイルはClaude Codeがプロジェクトを理解するためのガイドです。

## プロジェクト概要

Rikako - 問題集アプリ

## 技術スタック

### ローカル開発
- **バックエンド**: Go 1.24 + Echo v4.15.0
- **データベース**: PostgreSQL 18
- **マイグレーション**: golang-migrate/migrate
- **API仕様**: OpenAPI 3.0.3（oapi-codegenでコード生成）
- **ドキュメント**: MkDocs + tbls + Swagger UI
- **CI/CD**: GitHub Actions → GitHub Pages

### AWS環境
- **コンピュート**: AWS Lambda (コンテナイメージ) + Lambda Web Adapter 0.9.1
- **データベース**: Neon PostgreSQL (Serverless)
- **HTTPアクセス**:
  - 公開API: API Gateway HTTP API（`api.dev.rikako.org` / `api.rikako.org`）
  - 管理API: CloudFront + Basic Auth → Lambda Function URL (AWS_IAM + OAC)（`admin.dev.rikako.org/api` / `admin.rikako.org/api`）
- **画像配信**: S3 + CloudFront (OAC)
- **コンテンツ配信**: S3 + CloudFront（静的JSON）
- **コンテナレジストリ**: Amazon ECR (shared環境で管理)
- **シークレット管理**: AWS SSM Parameter Store (SecureString)。Lambda 環境変数には `ssm:/path` 形式の参照のみを保存し、アプリ起動時に `app/internal/secrets.Resolve` が実値を取得して `os.Setenv` で展開する
- **認証（API）**: Amazon Cognito User Pool（JWT検証）+ Cognito Identity Pool（匿名認証）
- **認証（CI/CD）**: GitHub Actions OIDC
- **アラート**: CloudWatch Alarm → SNS → Lambda (Python slack_notifier) → Slack
- **IaC**: Terraform (Neon Provider使用、S3ネイティブロック)
- **CI/CD**: GitHub Actions (tfcmt連携)

## ディレクトリ構成

```
├── app/
│   ├── cmd/
│   │   ├── server/         # 公開APIサーバー
│   │   ├── admin/          # 管理APIサーバー
│   │   └── importer/       # データインポートツール
│   ├── sql/
│   │   └── queries/        # sqlcクエリ定義（.sql）
│   ├── sqlc.yaml           # sqlc設定
│   ├── internal/
│   │   ├── api/            # 生成されたAPIコード（公開API）
│   │   ├── adminapi/       # 生成されたAPIコード（管理API）
│   │   ├── db/             # sqlc生成コード（編集禁止）
│   │   ├── handler/        # 公開APIハンドラー実装
│   │   ├── admin/          # 管理APIハンドラー実装
│   │   ├── secrets/        # Lambda 環境変数の SSM Parameter Store 自動解決
│   │   └── importer/       # インポーター実装
│   ├── Dockerfile.lambda   # Lambda用Dockerイメージ（公開API）
│   └── Dockerfile.admin    # Lambda用Dockerイメージ（管理API）
├── data/
│   ├── questions/          # 問題データ（YAML）
│   ├── workbooks/          # 問題集データ（YAML）
│   └── images/             # 画像ファイル（UUID.png）
├── docs/                   # ドキュメント
├── migrations/             # DBマイグレーションファイル
├── terraform/
│   ├── modules/
│   │   ├── api_gateway/    # API Gateway HTTP APIモジュール
│   │   ├── cloudfront/     # CloudFrontモジュール
│   │   ├── cognito/        # Cognito User Poolモジュール
│   │   ├── cognito_identity/ # Cognito Identity Poolモジュール
│   │   ├── ecr/            # ECRモジュール
│   │   ├── lambda/         # Lambdaモジュール
│   │   └── s3/             # S3モジュール
│   └── environments/
│       ├── shared/         # ECR（全環境共有）
│       ├── dev/            # Dev環境（Lambda + Neon + Image/Content CDN）
│       └── prod/           # Prod環境（dev と同構成、rikako.org 配下）
├── openapi.yaml            # 公開API仕様
├── openapi-admin.yaml      # 管理API仕様
└── .github/workflows/      # CI設定
    ├── deploy-api-dev.yml          # 公開APIデプロイ（ECRビルド&プッシュ + Lambda更新）
    ├── deploy-admin-api-dev.yml    # 管理APIデプロイ
    ├── deploy-admin-frontend-dev.yml # 管理フロントエンドデプロイ
    ├── apply-terraform-dev.yml     # main pushで dev のTerraform自動apply
    ├── plan-terraform.yml          # PR時にTerraform plan
    ├── plan-datasync.yml           # PR時に data 差分plan
    ├── docs.yml                    # ドキュメント生成・デプロイ
    └── migrate.yml                 # マイグレーションワークフロー
```

## データ形式

### 問題（questions）
- ファイル名: `{UUID}.yml`
- 形式: YAML
- フィールド: id, type, text, choices, correct, explanation, images

### 画像
- ファイル名: `{UUID}.png`
- 問題との関係: N:N（imagesテーブル経由）

## コマンド

### DB操作
```bash
# PostgreSQL起動/停止
docker compose up -d
docker compose down

# マイグレーション適用
docker run --rm -v $(pwd)/migrations:/migrations \
  migrate/migrate -path=/migrations \
  -database "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" up

# データインポート
cd app && go run ./cmd/importer -data ../data
```

### sqlc（DBクエリ生成）
```bash
# コード生成
cd app && go run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate

# クエリ追加手順:
# 1. app/sql/queries/*.sql にクエリを追加
# 2. 上記コマンドで再生成
# 3. internal/db/ の生成コードをコミット
```

### 公開APIサーバー
```bash
# サーバー起動
cd app && go run ./cmd/server

# ビルド
cd app && go build -o bin/server ./cmd/server
```

### 管理APIサーバー
```bash
# サーバー起動（ポート8081）
cd app && go run ./cmd/admin

# ビルド
cd app && go build -o bin/admin ./cmd/admin

# APIコード生成
cd app && oapi-codegen --config oapi-codegen-admin.yaml ../openapi-admin.yaml

# テスト
cd app && go test ./internal/admin/
```

環境変数: `DATABASE_URL`, `IMAGE_BASE_URL`, `IMAGE_S3_BUCKET`, `CONTENT_S3_BUCKET`, `AWS_REGION`, `PORT`(デフォルト: 8081)

### Terraform操作
```bash
# 事前に AWS_PROFILE を設定して SSO ログイン（docs/aws-setup.md 参照）
# export AWS_PROFILE=rikako-development-sso && aws sso login

# Plan/Apply（dev環境）
cd terraform/environments/dev
terraform plan
terraform apply
```

### ドキュメント生成
```bash
# スキーマドキュメント
docker run --rm -v $(pwd):/work -w /work \
  ghcr.io/k1low/tbls:v1.92.3 \
  doc "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" /work/docs/schema

# APIコード生成
cd app && oapi-codegen --config oapi-codegen.yaml ../openapi.yaml
```

## AWSインフラ構成

### アーキテクチャの特徴

1. **Lambda Web Adapter**
   - 既存のEcho HTTPサーバーをそのままLambdaで実行
   - PORT=8080でリクエストを受け取る
   - コード変更なしでLambda化
   - `/opt/extensions/lambda-adapter` に配置（ZunTalk方式）

2. **画像配信（S3 + CloudFront）**
   - 画像はDockerイメージに含めず、S3に格納しCloudFront（OAC）経由で配信
   - S3バケットはプライベート（パブリックアクセス無効）
   - 環境変数 `IMAGE_BASE_URL` にCloudFrontドメインを設定
   - APIは問題レスポンスの `images` フィールドに画像の完全URLを返す（リダイレクトなし）
   - 画像アップロード: `aws s3 sync data/images/ s3://rikako-images-development/`

3. **Cognito認証（API）**
   - Amazon Cognito User Poolでユーザー認証（将来のログイン用）
   - Amazon Cognito Identity Poolで匿名認証（デフォルト）
   - **認証方針**: 普段は匿名認証で利用し、機種変更時にログイン（User Pool）してデータを引き継ぐ
   - 匿名ユーザーは `X-Device-ID` ヘッダーで Identity ID を送信
   - サーバーはIdentity IDをユーザー識別子として `users` テーブルに保存
   - サーバーはJWT検証のみ（`app/internal/auth/`パッケージ）
   - 環境変数: `COGNITO_USER_POOL_ID`, `COGNITO_REGION`, `COGNITO_IDENTITY_POOL_ID`
   - 環境変数未設定時は認証スキップ（ローカル開発・CI用）
   - 認証不要エンドポイント: `GET /`, `GET /health`, `POST /answers`, `GET /users/me/wrong-answers`
   - JWKSはkid単位でRSA公開鍵をキャッシュ（TTL 1時間）

4. **OIDC認証（CI/CD）**
   - GitHub Actions用のOIDC ProviderとIAM Roleを作成
   - AWS_ACCESS_KEY_ID/SECRET_ACCESS_KEYが不要
   - セキュアな認証方式

4. **Neon Database**
   - Auto-suspend: 常時稼働（suspend_timeout_seconds = 0）
   - Auto-scaling: 0.25～2 CU（dev）
   - Region: ap-southeast-1（Singapore）
   - Terraformで完全管理（dev環境に直接記述）

### DB接続最適化（Lambda向け）

```go
db.SetMaxOpenConns(10)                  // 最大接続数
db.SetMaxIdleConns(2)                   // アイドル接続数
db.SetConnMaxLifetime(5 * time.Minute)  // 接続の最大ライフタイム
db.SetConnMaxIdleTime(1 * time.Minute)  // アイドル接続の最大時間
```

### Terraform構成

- **State管理**: 各環境のAWSアカウントにS3バケットで管理（S3ネイティブロック使用）
- **Shared環境** (AWSアカウント: 579039992557)
  - ECR（全環境で共有）
  - リポジトリ: `rikako-api`, `rikako-admin-api`
- **Dev環境** (AWSアカウント: 197865631794) — `apply-terraform-dev.yml` で main push 時に自動 apply
  - Lambda Function（公開API: API Gateway 経由、管理API: Function URL + OAC）
  - Neon PostgreSQL
  - S3 + CloudFront（画像配信 / コンテンツ配信）
  - OIDC Provider + IAM Role（GitHub Actions用）
  - CloudWatch アラーム + SNS + Python Lambda（slack_notifier）
- **Prod環境** (AWSアカウント: 211125415945) — 手動で `terraform apply`
  - Dev と同じリソース構成（カスタムドメインだけ rikako.org 配下に変更）
  - スロットリング: API Gateway HTTP API で `rate_limit=100, burst_limit=200`
- **SSM Parameter Store でのシークレット管理**:
  - `/rikako/<env>/openai-api-key`、`/rikako/<env>/slack-contact-webhook-url`、`/rikako/<env>/slack-alert-webhook-url` は手動で `aws ssm put-parameter --type SecureString` で登録
  - `/rikako/<env>/database-url` は Terraform が Neon の connection_uri から SecureString として登録
  - `/rikako/neon-api-key` は Terraform Provider 用、手動登録
  - Lambda 環境変数は `ssm:/rikako/<env>/...` のリテラル参照のみ。`app/internal/secrets.Resolve` および Python `_resolve_ssm` が起動時に実値を取得

### 環境

- **Dev環境** (AWSアカウント: 197865631794)
  - LP: https://rikako.org/ ※ LP は prod アカウントから配信
  - 公開API: https://api.dev.rikako.org/ （API Gateway HTTP API、rate=50/burst=100）
  - 管理画面: https://admin.dev.rikako.org/ （CloudFront + Basic Auth）
  - 管理API: https://admin.dev.rikako.org/api （CloudFront → Lambda Function URL、OAC + AWS_IAM）
  - Lambda関数名: `rikako-api-development` / `rikako-admin-api-development` / `rikako-slack-notifier-development`
  - Image CDN: https://image.dev.rikako.org/ (S3: `rikako-images-development`)
  - Content CDN: https://content.dev.rikako.org/ (S3: `rikako-content-development`)
  - Neon DB: `muddy-tree-64549662` (ap-southeast-1)
  - Cognito User Pool: `ap-northeast-1_DvsZzCoJw`
  - Cognito Identity Pool: `ap-northeast-1:51acc74e-ec8d-4de4-bfa1-84648ea45222`
  - Terraform State: `s3://rikako-dev-terraform-state`

- **Prod環境** (AWSアカウント: 211125415945)
  - LP: https://rikako.org/
  - 公開API: https://api.rikako.org/ （API Gateway HTTP API、rate=100/burst=200）
  - 管理画面: https://admin.rikako.org/ （CloudFront + Basic Auth）
  - 管理API: https://admin.rikako.org/api （CloudFront → Lambda Function URL、OAC + AWS_IAM）
  - Lambda関数名: `rikako-api-production` / `rikako-admin-api-production` / `rikako-slack-notifier-production`
  - Image CDN: https://image.rikako.org/ (S3: `rikako-images-production`)
  - Content CDN: https://content.rikako.org/ (S3: `rikako-content-production`)
  - Neon DB: `fragrant-poetry-87067174` (ap-southeast-1、エンドポイント `ep-misty-unit-aoxkoz1d`)
  - Cognito User Pool: `ap-northeast-1_d8LkqgsJU`
  - Terraform State: `s3://rikako-prod-terraform-state`
  - 自動 apply 無し、ローカルから `AWS_PROFILE=rikako-production-sso terraform apply` で反映

- **Shared環境** (AWSアカウント: 579039992557)
  - ECR: `rikako-api` / `rikako-admin-api`

### GitHub Actions ワークフロー

1. **deploy-api-dev.yml** - Dev公開APIデプロイ
   - Dockerイメージをビルド → ECRにプッシュ → Lambda関数を更新
   - ヘルスチェックで動作確認
   - OIDC認証でAWSアクセス

2. **deploy-admin-api-dev.yml** - Dev管理APIデプロイ
   - 管理APIのDockerイメージをビルド → ECRにプッシュ → Lambda関数を更新
   - スモークテスト: https://admin.dev.rikako.org/api

3. **plan-terraform.yml** - Terraform Plan CI
   - PRでterraform/以下の変更時に自動実行
   - shared/devの各環境でplanを実行
   - tfcmtでPRにplan結果をコメント

4. **apply-terraform-dev.yml** - Dev Terraform 自動 apply
   - main push で terraform/environments/dev/** または terraform/modules/** が変わったら自動 apply
   - OIDC + AdministratorAccess（dev のみ）

5. **docs.yml** - ドキュメント生成
   - スキーマドキュメント生成
   - MkDocsビルド
   - GitHub Pagesにデプロイ

6. **migrate.yml** - 手動マイグレーション
   - 環境選択（dev/prod）
   - 方向選択（up/down）
   - ステップ数指定

## コンテンツ配信（S3 + CloudFront）

iOSアプリはLambda APIではなく、S3上の静的JSONをCloudFront経由で取得する。

### 配信フロー
1. `data/` のYAMLを編集
2. `cd app && go run ./cmd/importer -data ../data` でDBに同期
3. `curl -X POST https://admin.dev.rikako.org/publish` でDB → S3にJSON書き出し
4. CloudFrontが60秒以内に新JSONを配信

### S3上のJSON構造
```
s3://rikako-content-development/
  v1/
    workbooks.json                # 問題集一覧
    workbooks/{id}.json           # 問題集詳細（問題含む）
    categories.json               # カテゴリ一覧
    categories/{id}.json          # カテゴリ詳細（問題集含む）
```

JSON形式は公開API（openapi.yaml）のレスポンスと完全一致。

## 注意事項

- IDはすべてUUID形式を使用
- 画像は複数の問題で使い回し可能（N:N関係）
- マイグレーションファイルは `YYYYMMDD_description.up.sql` / `.down.sql` の命名規則
- Lambda環境では接続プーリング設定が重要（Neon接続数制限対策）
