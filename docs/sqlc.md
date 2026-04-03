# sqlc（DBクエリ生成）

## 概要

本プロジェクトでは [sqlc](https://sqlc.dev/) を使って SQL クエリから型安全な Go コードを自動生成している。
手書きの `database/sql` コードを排除し、SQLインジェクションの防止とコンパイル時の型チェックを実現する。

## ディレクトリ構成

```
app/
├── sqlc.yaml                  # sqlc 設定ファイル
├── sql/
│   └── queries/               # SQL クエリ定義
│       ├── questions.sql      # 問題関連
│       ├── categories.sql     # カテゴリ関連
│       ├── workbooks.sql      # 問題集関連
│       ├── images.sql         # 画像関連
│       ├── answers.sql        # 回答履歴関連
│       └── importer.sql       # データインポート用
├── internal/
│   └── db/                    # 生成されたコード（編集禁止）
│       ├── db.go              # DB接続・トランザクション
│       ├── models.go          # テーブルモデル
│       ├── querier.go         # インターフェース定義
│       ├── questions.sql.go
│       ├── categories.sql.go
│       ├── workbooks.sql.go
│       ├── images.sql.go
│       ├── answers.sql.go
│       └── importer.sql.go
```

## コード生成

```bash
cd app
go run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate
```

`internal/db/` 配下のファイルが再生成される。生成コードは直接編集しないこと。

## 設定（sqlc.yaml）

```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "sql/queries"        # クエリ定義ディレクトリ
    schema: "../migrations"       # マイグレーションファイルをスキーマとして使用
    gen:
      go:
        package: "db"
        out: "internal/db"
        sql_package: "database/sql"
        emit_json_tags: true
        emit_interface: true      # Querier インターフェース生成
        emit_empty_slices: true   # nil ではなく空スライスを返す
```

- **schema**: マイグレーションファイル（`migrations/*.up.sql`）をスキーマ定義として使用。別途スキーマファイルを管理する必要がない
- **emit_interface**: `Querier` インターフェースが生成され、テストでのモック差し替えが容易になる

## クエリの書き方

### 基本構文

```sql
-- name: GetQuestionByID :one
SELECT q.id, qsc.text, qsc.explanation
FROM questions q
JOIN questions_single_choice qsc ON q.id = qsc.question_id
WHERE q.id = $1;
```

| アノテーション | 意味 |
|-------------|------|
| `:one` | 1行を返す（`QueryRowContext`） |
| `:many` | 複数行を返す（`QueryContext`） |
| `:exec` | 結果を返さない（`ExecContext`） |
| `:execresult` | `sql.Result` を返す（`ExecContext`） |

### 配列パラメータ

PostgreSQL の `ANY` を使用する:

```sql
-- name: GetImageURLsByQuestionIDs :many
SELECT question_id, path
FROM question_images qi
JOIN images i ON qi.image_id = i.id
WHERE qi.question_id = ANY($1::bigint[])
ORDER BY qi.question_id, qi.order_index;
```

Go 側では `[]int64` として渡せる。`pq.Array` は不要。

## 使い方

### 基本

```go
queries := db.New(sqlDB)
row, err := queries.GetQuestionByID(ctx, questionID)
```

### トランザクション

`WithTx` で同一トランザクション上のクエリオブジェクトを作成する:

```go
tx, err := sqlDB.Begin()
defer tx.Rollback()

qtx := queries.WithTx(tx)
qtx.CreateQuestion(ctx, ...)
qtx.CreateSingleChoice(ctx, ...)

tx.Commit()
```

admin handler と importer がこのパターンを使用している。

## クエリファイル一覧

| ファイル | 内容 |
|---------|------|
| `questions.sql` | 問題の CRUD、選択肢の取得・作成・更新・削除 |
| `categories.sql` | カテゴリの CRUD、カテゴリ別問題集取得 |
| `workbooks.sql` | 問題集の CRUD、問題集内の問題取得（選択肢JOIN版含む） |
| `images.sql` | 画像URLの取得（単一・複数問題ID対応）、画像の作成・紐付け |
| `answers.sql` | ユーザーの Upsert、回答記録、間違えた問題の取得 |
| `importer.sql` | 全テーブルの DELETE、明示的ID指定での INSERT |

## クエリを追加・変更する手順

1. `app/sql/queries/*.sql` にクエリを追加・編集
2. `cd app && go run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate` で再生成
3. `internal/db/` の生成コードをコミット
4. handler 等で新しいクエリを使用

スキーマ変更（カラム追加等）がある場合は、先にマイグレーションファイルを作成すること。sqlc はマイグレーションファイルをスキーマとして読み取る。
