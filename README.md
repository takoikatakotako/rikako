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
- 問題データ（900問）
- 画像（115枚）
- 問題集（1件、100問）

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
| `GET /images/{id}` | 画像取得 |

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

- **コンピュート**: AWS Lambda (コンテナイメージ) + Lambda Web Adapter
- **データベース**: Neon PostgreSQL (Serverless)
- **コンテナレジストリ**: Amazon ECR
- **IaC**: Terraform
- **CI/CD**: GitHub Actions

### 初回セットアップ

#### 1. Bootstrap（Terraform State管理リソースの作成）

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

これで以下のリソースが作成されます：
- S3バケット: `rikako-terraform-state`
- DynamoDBテーブル: `rikako-terraform-locks`

#### 2. Neon API Keyの取得

https://console.neon.tech/app/settings/api-keys でAPIキーを作成します。

#### 3. GitHub Secretsの設定

リポジトリの Settings → Secrets → Actions に以下を追加:

| Secret名 | 説明 |
|---------|------|
| `AWS_ACCESS_KEY_ID` | AWSアクセスキー |
| `AWS_SECRET_ACCESS_KEY` | AWSシークレットキー |
| `NEON_API_KEY` | NeonのAPIキー |

#### 4. Shared環境のデプロイ（ECR）

```bash
cd terraform/environments/shared
terraform init
terraform apply
```

#### 5. Dev環境のデプロイ

```bash
cd terraform/environments/dev
terraform init
terraform apply -var="neon_api_key=$NEON_API_KEY"
```

### 以降のデプロイ

GitHub ActionsのDeployワークフローを実行するだけでOK:

- **自動デプロイ**: `main`ブランチへのpushで自動実行
- **手動デプロイ**: Actions → Deploy to AWS → Run workflow

### デプロイフロー

1. ECRにDockerイメージをビルド&プッシュ
2. Terraform apply（Lambda + Neon作成）
3. データベースマイグレーション実行
4. データインポート（初回のみ）
5. Lambda関数の更新
6. ヘルスチェック

### マイグレーション（手動実行）

GitHub Actions経由でマイグレーションを実行:

Actions → Run Database Migration → Run workflow

- **Environment**: `dev` または `prod`
- **Direction**: `up` または `down`
- **Steps**: 空欄（すべて）または数値（ステップ数）

### Function URLの確認

```bash
cd terraform/environments/dev
terraform output function_url
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
terraform destroy -var="neon_api_key=$NEON_API_KEY"

# Shared環境の削除
cd terraform/environments/shared
terraform destroy

# Bootstrap環境の削除
cd terraform/bootstrap
terraform destroy
```
