# 問題形式仕様書

このドキュメントでは、アプリで対応する問題形式とそのDB設計について説明します。

## 対応する問題形式

| 形式 | type値 | 説明 |
|-----|--------|------|
| 単一選択 | `single_choice` | 複数の選択肢から1つを選ぶ |
| 複数選択 | `multiple_choice` | 複数の選択肢から該当するものを全て選ぶ |
| 記述式 | `text_input` | 自由にテキストを入力する |
| 穴埋め | `fill_in_blank` | 文章中の空欄を埋める |
| 並べ替え | `ordering` | 項目を正しい順序に並べ替える |
| マッチング | `matching` | 左右の項目を正しく組み合わせる |

---

## 各形式の詳細

### 単一選択 (single_choice)

複数の選択肢から正解を1つ選ぶ形式。

**例:**
```
Q: 日本の首都はどこですか？
- [ ] 大阪
- [x] 東京
- [ ] 京都
- [ ] 名古屋
```

**特徴:**
- 選択肢は2〜10個程度
- 正解は必ず1つ

---

### 複数選択 (multiple_choice)

複数の選択肢から該当するものを全て選ぶ形式。

**例:**
```
Q: 次のうち、プログラミング言語はどれですか？（複数選択可）
- [x] Python
- [ ] HTML
- [x] Java
- [x] Swift
```

**特徴:**
- 正解が複数ある
- 全て正解した場合のみ正答とする（部分点の有無は設定可能）

---

### 記述式 (text_input)

テキストを自由に入力する形式。

**例:**
```
Q: 「吾輩は猫である」の作者は誰ですか？
A: 夏目漱石
```

**特徴:**
- 複数の正解パターンを登録可能（例: 「夏目漱石」「夏目 漱石」「なつめそうせき」）
- 大文字・小文字の区別設定が可能

---

### 穴埋め (fill_in_blank)

文章中の空欄を埋める形式。

**例:**
```
Q: {{1}}年に日本国憲法が施行された。
A: 1947
```

**特徴:**
- 1つの問題に複数の空欄を設定可能
- 各空欄に複数の正解パターンを登録可能

---

### 並べ替え (ordering)

項目を正しい順序に並べ替える形式。

**例:**
```
Q: 次の出来事を古い順に並べ替えてください。
1. 明治維新
2. 関ヶ原の戦い
3. 第二次世界大戦
4. 鎌倉幕府成立

正解: 4 → 2 → 1 → 3
```

**特徴:**
- 表示時はシャッフルして出題
- 完全一致で正答判定

---

### マッチング (matching)

左右の項目を正しく組み合わせる形式。

**例:**
```
Q: 国と首都を正しく組み合わせてください。

日本     ●────● ワシントンD.C.
アメリカ ●────● 東京
イギリス ●────● ロンドン
```

**特徴:**
- 左右の項目数は同じ
- 表示時は右側をシャッフル

---

## DB設計 (CTI方式)

Class Table Inheritance方式を採用し、共通テーブルと形式別テーブルに分離します。

### テーブル一覧

```
workbooks                    # 問題集
questions                    # 問題（共通）
├── question_choices         # 選択肢（単一選択・複数選択）
├── question_text_inputs     # 記述式設定
├── question_text_answers    # 記述式の正解パターン
├── question_fill_blanks     # 穴埋め設定
├── question_blank_answers   # 穴埋めの正解パターン
├── question_ordering_items  # 並べ替え項目
└── question_matching_pairs  # マッチングペア
users                        # ユーザー
user_answers                 # 回答（共通）
├── user_choice_answers      # 選択式の回答
├── user_text_answers        # 記述式の回答
├── user_ordering_answers    # 並べ替えの回答
└── user_matching_answers    # マッチングの回答
```

### 共通テーブル

#### workbooks（問題集）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| title | VARCHAR(255) | タイトル |
| description | TEXT | 説明 |
| created_at | TIMESTAMP | 作成日時 |

#### questions（問題）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| workbook_id | BIGINT | 問題集ID（FK） |
| type | ENUM | 問題形式 |
| text | TEXT | 問題文 |
| explanation | TEXT | 解説 |
| order_index | INT | 並び順 |
| created_at | TIMESTAMP | 作成日時 |

### 形式別テーブル

#### question_choices（選択肢）

単一選択・複数選択で使用。

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK） |
| choice_index | INT | 選択肢の順番 |
| text | VARCHAR(500) | 選択肢テキスト |
| is_correct | BOOLEAN | 正解かどうか |

#### question_text_inputs（記述式設定）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK, UNIQUE） |
| case_sensitive | BOOLEAN | 大文字小文字を区別するか |

#### question_text_answers（記述式の正解）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK） |
| answer_text | VARCHAR(500) | 正解テキスト |

#### question_fill_blanks（穴埋め設定）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK, UNIQUE） |
| template | TEXT | テンプレート（例: `{{1}}年に...`） |

#### question_blank_answers（穴埋めの正解）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK） |
| blank_index | INT | 空欄番号 |
| answer_text | VARCHAR(500) | 正解テキスト |

#### question_ordering_items（並べ替え項目）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK） |
| display_index | INT | 表示順 |
| correct_position | INT | 正解の位置 |
| text | VARCHAR(500) | 項目テキスト |

#### question_matching_pairs（マッチングペア）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGINT | 主キー |
| question_id | BIGINT | 問題ID（FK） |
| pair_index | INT | ペア番号 |
| left_text | VARCHAR(500) | 左側テキスト |
| right_text | VARCHAR(500) | 右側テキスト |

---

## 今後の拡張予定

- 画像付き問題
- 音声問題
- 時間制限設定
- 難易度設定
- タグ・カテゴリ機能
