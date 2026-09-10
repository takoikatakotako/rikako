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
# plan
go run ./cmd/datasync -data ../data -env dev plan

# apply
go run ./cmd/datasync -data ../data -env dev apply
```

AWS SSM Parameter Store (`/rikako/development/database-url`) からNeonの接続URLを取得して接続します。
事前に `AWS_PROFILE` の設定と `aws sso login` が必要です（[AWS CLI セットアップ](aws-setup.md) 参照）。

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

## 接続まわりの前提

- **DBドライバは pgx(stdlib) を simple protocol で駆動**する（Issue #291 / #292 で lib/pq から移行）。pgx は SCRAM channel binding に対応しているため、接続文字列に `channel_binding=require` が付いていても構わない。
- **datasync は direct エンドポイントに接続する。** pooled endpoint への切替を行う `dbconn.Pooled` を呼ぶのは `cmd/server` と `cmd/admin` だけで、datasync は呼ばない。接続方針の一覧は [runbook](runbook.md#neon-pooling) を参照。
- 接続URLは SSM から取得する。dev は `/rikako/development/database-url`、prod は `/rikako/production/database-url`。パラメータ名は Terraform が作る `/<project>/<local.environment>/database-url` と一致している。
- `DATABASE_URL` 環境変数を直接渡せば `-env` より優先される。SSM がズレているときの暫定回避に使える。

> **パラメータは環境ごとに 1 本。** datasync も Lambda も同じものを読む。
> Terraform は `lifecycle.ignore_changes = [value]` を付けていて**初期値を入れるだけ**なので、
> Neon 側でロールパスワードが変わったときの再登録は手作業（out-of-band）になる。
> `aws ssm put-parameter --overwrite` で更新してよく、次の `terraform apply` で巻き戻ることはない。

## CI（plan-datasync）

`.github/workflows/plan-datasync.yml` の plan 実行ステップは `set -o pipefail` + `tee` で、
datasync が非ゼロ終了したときにステップが失敗するようになっている（2026-06-13 修正済み）。

`tee` により datasync の標準出力が public リポジトリの CI ログに出るため、**DSN を生のまま
ログや標準出力に出さないこと**。datasync は接続先表示のパスワードを `url.Redacted()` で
マスクしている。
