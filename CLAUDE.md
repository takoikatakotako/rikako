# CLAUDE.md

このファイルはClaude Codeがプロジェクトを理解するためのガイドです。

## プロジェクト概要

Rikako - 問題集アプリ

## 技術スタック

### ローカル開発
- **バックエンド**: Go 1.23 + Echo v4
- **データベース**: PostgreSQL 18
- **マイグレーション**: golang-migrate/migrate
- **API仕様**: OpenAPI 3.0.3（oapi-codegenでコード生成）
- **ドキュメント**: MkDocs + tbls + Swagger UI
- **CI/CD**: GitHub Actions → GitHub Pages

### AWS本番環境
- **コンピュート**: AWS Lambda (コンテナイメージ) + Lambda Web Adapter
- **データベース**: Neon PostgreSQL (Serverless)
- **HTTPアクセス**: Lambda Function URL
- **コンテナレジストリ**: Amazon ECR
- **IaC**: Terraform (Neon Provider使用)
- **CI/CD**: GitHub Actions

## ディレクトリ構成

```
├── app/
│   ├── cmd/
│   │   ├── server/         # APIサーバー
│   │   └── importer/       # データインポートツール
│   ├── internal/
│   │   ├── api/            # 生成されたAPIコード
│   │   ├── handler/        # ハンドラー実装
│   │   └── importer/       # インポーター実装
│   └── Dockerfile.lambda   # Lambda用Dockerイメージ
├── data/
│   ├── questions/          # 問題データ（YAML）
│   ├── workbooks/          # 問題集データ（YAML）
│   └── images/             # 画像ファイル（UUID.png）
├── docs/                   # ドキュメント
├── migrations/             # DBマイグレーションファイル
├── terraform/
│   ├── bootstrap/          # S3/DynamoDBリソース
│   ├── modules/
│   │   ├── ecr/            # ECRモジュール
│   │   ├── lambda/         # Lambdaモジュール
│   │   └── neon/           # Neonモジュール
│   └── environments/
│       ├── shared/         # ECR（全環境共有）
│       ├── dev/            # Dev環境
│       └── prod/           # Prod環境
├── openapi.yaml            # API仕様
└── .github/workflows/      # CI設定
    ├── deploy.yml          # デプロイワークフロー
    └── migrate.yml         # マイグレーションワークフロー
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

### APIサーバー
```bash
# サーバー起動
cd app && go run ./cmd/server

# ビルド
cd app && go build -o bin/server ./cmd/server
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

2. **画像の扱い**
   - 115枚の画像（合計約1MB）をDockerイメージに含める
   - S3を使わずシンプルな構成
   - `/app/data/images` に配置

3. **データインポート**
   - GitHub Actionsで実行（初回デプロイ時のみ）
   - データベースが空の場合のみ実行
   - `-check-only`フラグで問題数確認

4. **Neon Database**
   - Auto-suspend: 5分アイドル
   - Auto-scaling: 0.25～2/4 CU（dev/prod）
   - Terraformで完全管理

### DB接続最適化（Lambda向け）

```go
db.SetMaxOpenConns(10)                  // 最大接続数
db.SetMaxIdleConns(2)                   // アイドル接続数
db.SetConnMaxLifetime(5 * time.Minute)  // 接続の最大ライフタイム
db.SetConnMaxIdleTime(1 * time.Minute)  // アイドル接続の最大時間
```

### Terraform構成

- **Bootstrap**: S3（state）+ DynamoDB（locks）
- **Shared**: ECR（全環境で共有）
- **Dev/Prod**: Lambda + Neon（環境ごと）

### GitHub Actions ワークフロー

1. **deploy.yml** - メインデプロイ
   - ECRにイメージプッシュ
   - Terraform apply
   - マイグレーション実行
   - データインポート（初回のみ）
   - Lambda更新
   - ヘルスチェック

2. **migrate.yml** - 手動マイグレーション
   - 環境選択（dev/prod）
   - 方向選択（up/down）
   - ステップ数指定

## 注意事項

- IDはすべてUUID形式を使用
- 画像は複数の問題で使い回し可能（N:N関係）
- マイグレーションファイルは `YYYYMMDD_description.up.sql` / `.down.sql` の命名規則
- Lambda環境では接続プーリング設定が重要（Neon接続数制限対策）
