# CLAUDE.md

このファイルはClaude Codeがプロジェクトを理解するためのガイドです。

## プロジェクト概要

Rikako - 問題集アプリ

## 技術スタック

- **バックエンド**: Go 1.x + Echo v4
- **データベース**: PostgreSQL 18
- **マイグレーション**: golang-migrate/migrate
- **API仕様**: OpenAPI 3.0.3（oapi-codegenでコード生成）
- **ドキュメント**: MkDocs + tbls + Swagger UI
- **CI/CD**: GitHub Actions → GitHub Pages

## ディレクトリ構成

```
├── app/
│   ├── cmd/
│   │   ├── server/    # APIサーバー
│   │   └── importer/  # データインポートツール
│   └── internal/
│       ├── api/       # 生成されたAPIコード
│       ├── handler/   # ハンドラー実装
│       └── importer/  # インポーター実装
├── data/
│   ├── questions/     # 問題データ（YAML）
│   ├── workbooks/     # 問題集データ（YAML）
│   └── images/        # 画像ファイル（UUID.png）
├── docs/              # ドキュメント
├── migrations/        # DBマイグレーションファイル
├── openapi.yaml       # API仕様
└── .github/workflows/ # CI設定
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

## 注意事項

- IDはすべてUUID形式を使用
- 画像は複数の問題で使い回し可能（N:N関係）
- マイグレーションファイルは `YYYYMMDD_description.up.sql` / `.down.sql` の命名規則
