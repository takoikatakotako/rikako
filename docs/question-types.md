# 問題形式仕様書

このドキュメントでは、アプリで対応する問題形式とそのDB設計について説明します。

## 対応する問題形式

| 形式 | 説明 |
|-----|------|
| 単一選択 | 複数の選択肢から1つを選ぶ |

---

## 単一選択 (single_choice)

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

**YAMLサンプル:**
```yaml
# 令和7年度 ITパスポート 公開問題 問1
id: 18477eaa-639a-4515-b21c-90b924341c16
type: single_choice
text: |
  A社がB社に作業の一部を請負契約で委託している。
  作業形態a〜cのうち、いわゆる偽装請負とみなされる状態だけを全て挙げたものはどれか。

  a B社の従業員が、A社内において、A社の責任者の指揮命令の下で、請負契約で取り決めた作業を行っている。
  b B社の従業員が、A社内において、B社の責任者の指揮命令の下で、請負契約で取り決めた作業を行っている。
  c B社の従業員が、B社内において、A社の責任者の指揮命令の下で、請負契約で取り決めた作業を行っている。
choices:
  - "a"
  - "a, b"
  - "a, c"
  - "b, c"
correct: 2
explanation: |
  偽装請負とは、請負契約でありながら発注元が直接指揮命令を行う状態。
  a と c は A社が指揮命令しているため偽装請負に該当する。
```

---

## DB設計

### テーブル一覧

```
questions                         # 問題（共通）
└── questions_single_choice       # 単一選択問題
    └── questions_single_choice_choices  # 選択肢
```

### questions（共通）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGSERIAL | 主キー |
| type | VARCHAR(50) | 問題形式（single_choice など） |
| created_at | TIMESTAMP | 作成日時 |
| updated_at | TIMESTAMP | 更新日時 |

### questions_single_choice（単一選択問題）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGSERIAL | 主キー |
| question_id | BIGINT | 問題ID（FK, UNIQUE） |
| text | TEXT | 問題文 |
| explanation | TEXT | 解説 |
| created_at | TIMESTAMP | 作成日時 |
| updated_at | TIMESTAMP | 更新日時 |

### questions_single_choice_choices（選択肢）

| カラム | 型 | 説明 |
|-------|-----|------|
| id | BIGSERIAL | 主キー |
| single_choice_id | BIGINT | 単一選択問題ID（FK） |
| choice_index | INT | 選択肢の順番 |
| text | TEXT | 選択肢テキスト |
| is_correct | BOOLEAN | 正解かどうか |

---

## 今後の拡張予定

- 複数選択
- 記述式
- 穴埋め
- 並べ替え
- マッチング
