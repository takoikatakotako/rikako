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
