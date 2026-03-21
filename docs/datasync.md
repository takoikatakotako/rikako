# データ同期 (datasync)

`datasync` は、YAMLデータファイルを正（source of truth）として、データベースとの差分確認・反映を行うCLIツールです。Terraformの `plan` / `apply` と同じ考え方で動作します。

## 対象リソース

| リソース | YAMLパス | DBテーブル |
|----------|----------|------------|
| 画像 | `data/images/*.png` | `images` |
| 問題 | `data/questions/*.yml` | `questions`, `questions_single_choice`, `questions_single_choice_choices`, `question_images` |
| 問題集 | `data/workbooks/*.yml` | `workbooks`, `workbook_questions` |
| カテゴリ | `data/categories/*.yml` | `categories` |

## 使い方

### 差分確認 (plan)

```bash
cd app && go run ./cmd/datasync -data ../data plan
```

YAMLとDBの差分をterraform風に表示します。データベースへの変更は行いません。

```
Images:
  (no changes)

Questions:
  + 981 (新しい問題のテキスト...)
  ~ 42
      text: "旧テキスト..." → "新テキスト..."
  - 500 (削除される問題のテキスト...)

Workbooks:
  (no changes)

Categories:
  (no changes)

Plan: 1 to add, 1 to change, 1 to destroy.
```

- `+` 追加（YAMLにあるがDBにない）
- `~` 変更（YAMLとDBで内容が異なる）
- `-` 削除（DBにあるがYAMLにない）

### 差分反映 (apply)

```bash
cd app && go run ./cmd/datasync -data ../data apply
```

planと同じ差分を計算し、トランザクション内でDBに反映します。

## 接続先の切り替え

`--env` フラグで接続先を選択できます。

### ローカルDB（デフォルト）

```bash
go run ./cmd/datasync -data ../data plan
# または明示的に
go run ./cmd/datasync -data ../data -env local plan
```

`localhost:5432` のPostgreSQLに接続します。事前に `docker compose up -d postgres` でDBを起動してください。

### dev環境（Neon）

```bash
# 事前にSSOログイン
aws sso login --profile rikako-development-sso

# plan
go run ./cmd/datasync -data ../data -env dev plan

# apply
go run ./cmd/datasync -data ../data -env dev apply
```

AWS SSM Parameter Store (`/rikako/dev/database-url`) からNeonの接続URLを取得して接続します。

### DATABASE_URL 直接指定

```bash
DATABASE_URL="postgres://user:pass@host:5432/db?sslmode=require" \
  go run ./cmd/datasync -data ../data plan
```

`DATABASE_URL` 環境変数が設定されている場合は `--env` フラグより優先されます。

## データ形式

### 問題 (questions)

```yaml
id: 1
type: single_choice
text: 問題文
choices:
- 選択肢A
- 選択肢B
- 選択肢C
correct: 1
explanation: 解説文
images:
- 42
- 43
```

- `id`: int（ファイル名と一致: `1.yml`）
- `correct`: 0-indexed の正解選択肢番号
- `images`: 画像ID（`data/images/{id}.png` と対応）

### 問題集 (workbooks)

```yaml
id: 1
title: 問題集タイトル
description: 説明文
questions:
- 1   # 問題ID
- 2
- 3
```

- `questions` の並び順がそのまま出題順序になります

### カテゴリ (categories)

```yaml
id: 1
title: カテゴリ名
description: 説明文
workbooks:
- 1   # 問題集ID
- 2
```

## 注意事項

- apply はトランザクション内で実行されるため、途中でエラーが発生した場合はロールバックされます
- 明示的IDでINSERTするため、apply後にシーケンス（auto increment）は自動でリセットされます
- `choices` が空の問題では `correct` の差分比較はスキップされます
