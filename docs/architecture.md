# アーキテクチャ

## 全体構成

```mermaid
graph TB
    subgraph Client
        iOS[iOS App]
        Android[Android App]
    end

    subgraph Admin
        AdminClient[Admin Client]
    end

    subgraph AWS - Dev Account
        FURL[Lambda Function URL<br/>公開API]
        Lambda[Lambda + Web Adapter<br/>公開API]
        AdminFURL[Lambda Function URL<br/>管理API]
        AdminLambda[Lambda + Web Adapter<br/>管理API]
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
    AdminClient --> AdminFURL
    AdminFURL --> AdminLambda
    AdminLambda --> DB
    AdminLambda -->|Presigned URL| S3
    CF --> S3

    Actions -->|OIDC| ECR
    Actions -->|OIDC| Lambda
    Actions -->|OIDC| AdminLambda
    ECR -->|Image| Lambda
    ECR -->|Image| AdminLambda
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
    GH->>GA: Trigger deploy-api-dev.yml
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

## 認証方針

普段は**匿名認証（Cognito Identity Pool）**でユーザー登録なしに利用できる。機種変更時は**ログイン（Cognito User Pool）**してデータを引き継ぐ。

```mermaid
graph LR
    subgraph 通常利用
        App1[iOS App] -->|GetId| CIP[Cognito Identity Pool]
        CIP -->|Identity ID| App1
        App1 -->|X-Device-ID ヘッダー| API[Public API]
        API -->|保存| DB[(users / user_answers)]
    end

    subgraph 機種変更
        App2[iOS App] -->|ログイン| CUP[Cognito User Pool]
        CUP -->|JWT| App2
        App2 -->|JWT| API2[Public API]
        API2 -->|Identity ID に sub を紐づけ| DB
    end
```

- **Identity ID**: Cognito Identity Pool から取得される匿名ユーザー識別子。Keychainに永続化
- **回答履歴**: `POST /answers` でクイズ完了時にサーバーに送信、`user_answers` テーブルに保存
- **間違えた問題**: `GET /users/me/wrong-answers` で最新回答が不正解の問題を取得

## 管理API

管理APIは公開APIとは別のLambda関数として動作します。詳細は [管理API設計](admin-api.md) を参照。

- **エントリーポイント**: `app/cmd/admin/main.go`
- **OpenAPI仕様**: `openapi-admin.yaml`
- **機能**: 問題・問題集のCRUD、画像Presigned URL発行
- **デプロイ**: Lambda + Lambda Web Adapter（公開APIと同じパターン）

## インフラ構成

| リソース | 用途 | 環境 |
|---------|------|------|
| Lambda + Web Adapter | 公開APIサーバー | Dev |
| Lambda + Web Adapter | 管理APIサーバー | Dev |
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
| `modules/cognito` | Cognito User Pool + Client |
| `modules/cognito_identity` | Cognito Identity Pool + IAM Role (unauthenticated) |

環境レベルで組み合わせて使用します（例: `dev/image_cdn.tf` で `s3` + `cloudfront` を組み合わせ）。
