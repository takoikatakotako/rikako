# アーキテクチャ

## 全体構成

```mermaid
graph TB
    subgraph Client
        iOS[iOS App]
        Android[Android App]
    end

    subgraph AWS - Dev Account
        FURL[Lambda Function URL]
        Lambda[Lambda + Web Adapter]
        S3[S3 Bucket<br/>rikako-images-development]
        CF[CloudFront<br/>OAC]
        SSM[SSM Parameter Store<br/>Neon API Key]
    end

    subgraph Neon
        DB[(PostgreSQL)]
    end

    subgraph AWS - Shared Account
        ECR[ECR<br/>rikako-api]
    end

    subgraph GitHub
        Repo[Repository]
        Actions[GitHub Actions]
    end

    iOS --> FURL
    Android --> FURL
    iOS --> CF
    Android --> CF
    FURL --> Lambda
    Lambda --> DB
    CF --> S3

    Actions -->|OIDC| ECR
    Actions -->|OIDC| Lambda
    ECR -->|Image| Lambda
    Repo --> Actions
```

## デプロイフロー

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as ECR (Shared)
    participant Lambda as Lambda (Dev)
    participant FURL as Function URL

    Dev->>GH: Push to main
    GH->>GA: Trigger deploy-dev.yml
    GA->>GA: Docker Build
    GA->>ECR: Push Image (OIDC)
    GA->>Lambda: Update Function Code (OIDC)
    GA->>Lambda: Wait for Update
    GA->>FURL: Health Check (/health)
    FURL-->>GA: 200 OK
```

## 画像配信

```mermaid
graph LR
    Client[Client App] -->|1. GET /questions| Lambda
    Lambda -->|2. Response with image URLs| Client
    Client -->|3. GET image| CF[CloudFront]
    CF -->|OAC| S3[S3 Bucket]
```

APIは問題レスポンスの `images` フィールドに画像の完全URL（`https://xxx.cloudfront.net/uuid.png`）を返します。
クライアントはそのURLに直接アクセスして画像を取得します。

## Terraform CI

```mermaid
graph LR
    PR[Pull Request] -->|terraform/** 変更| Plan[Terraform Plan]
    Plan -->|shared| Shared[Shared Account]
    Plan -->|dev| Dev[Dev Account]
    Plan -->|tfcmt| Comment[PR Comment]
```

PRで `terraform/` 以下のファイルが変更されると、自動的に `terraform plan` が実行され、結果がPRにコメントされます。

## インフラ構成

| リソース | 用途 | 環境 |
|---------|------|------|
| Lambda + Web Adapter | API サーバー | Dev |
| Lambda Function URL | HTTP エンドポイント | Dev |
| Neon PostgreSQL | データベース | External |
| S3 | 画像ストレージ | Dev |
| CloudFront (OAC) | 画像 CDN | Dev |
| ECR | コンテナレジストリ | Shared |
| SSM Parameter Store | シークレット管理 | Dev |
| S3 | Terraform State | Shared / Dev |

## Terraform モジュール

モジュールはリソースのラッパーとして設計されています。

| モジュール | 内容 |
|-----------|------|
| `modules/s3` | S3 バケット + パブリックアクセスブロック |
| `modules/cloudfront` | CloudFront ディストリビューション + OAC |
| `modules/lambda` | Lambda + IAM Role + CloudWatch Logs + Function URL |
| `modules/ecr` | ECR リポジトリ + ライフサイクルポリシー |

環境レベルで組み合わせて使用します（例: `dev/image_cdn.tf` で `s3` + `cloudfront` を組み合わせ）。
