# Rikako

問題集アプリ

## セットアップ

### PostgreSQL 起動

```bash
docker compose up -d
```

### PostgreSQL 停止

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

## スキーマドキュメント生成

```bash
docker run --rm \
  -v $(pwd):/work \
  ghcr.io/k1low/tbls:v1.92.3 \
  doc "postgres://rikako:password@host.docker.internal:5432/rikako?sslmode=disable" /work/docs/schema
```

生成されたドキュメントは `docs/schema/` に出力されます。
