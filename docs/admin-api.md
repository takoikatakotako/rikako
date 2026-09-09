# 管理API (Admin API)

問題・問題集を管理するためのAPIサーバー。公開API (`app/cmd/server/`) とは別のバイナリとして動作する。

## 概要

| 項目 | 値 |
|------|-----|
| エントリーポイント | `app/cmd/admin/main.go` |
| OpenAPI仕様 | `openapi-admin.yaml` |
| デフォルトポート | 8081 |
| 認証 | なし（将来追加予定） |
| デプロイ | Lambda + Lambda Web Adapter（#77 完了後） |

## エンドポイント

### System

| Method | Path | 説明 |
|--------|------|------|
| GET | `/` | ルート |
| GET | `/health` | ヘルスチェック |

### Questions (CRUD)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/questions` | 問題一覧（ページネーション対応） |
| POST | `/questions` | 問題作成 |
| GET | `/questions/{questionId}` | 問題取得 |
| PUT | `/questions/{questionId}` | 問題更新 |
| DELETE | `/questions/{questionId}` | 問題削除 |

### Workbooks (CRUD)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/workbooks` | 問題集一覧（ページネーション対応） |
| POST | `/workbooks` | 問題集作成 |
| GET | `/workbooks/{workbookId}` | 問題集取得（問題含む） |
| PUT | `/workbooks/{workbookId}` | 問題集更新 |
| DELETE | `/workbooks/{workbookId}` | 問題集削除 |

### Categories (CRUD)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/categories` | カテゴリ一覧 |
| POST | `/categories` | カテゴリ作成 |
| GET | `/categories/{categoryId}` | カテゴリ取得 |
| PUT | `/categories/{categoryId}` | カテゴリ更新 |
| DELETE | `/categories/{categoryId}` | カテゴリ削除 |

### Announcements (CRUD)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/announcements` | お知らせ一覧 |
| POST | `/announcements` | お知らせ作成 |
| GET | `/announcements/{announcementId}` | お知らせ取得 |
| PUT | `/announcements/{announcementId}` | お知らせ更新 |
| DELETE | `/announcements/{announcementId}` | お知らせ削除 |

### Apps (CRUD)

アプリ（flavor）ごとの設定。`app_slug` 単位で最低バージョンなどを持つ。

| Method | Path | 説明 |
|--------|------|------|
| GET | `/apps` | アプリ一覧 |
| POST | `/apps` | アプリ作成 |
| GET | `/apps/{appId}` | アプリ取得 |
| PUT | `/apps/{appId}` | アプリ更新 |
| DELETE | `/apps/{appId}` | アプリ削除 |

### App Status

| Method | Path | 説明 |
|--------|------|------|
| GET | `/app-status` | アプリステータス取得（メンテナンス表示など） |
| PUT | `/app-status` | アプリステータス更新 |

### Users（参照のみ）

| Method | Path | 説明 |
|--------|------|------|
| GET | `/users` | ユーザー一覧 |
| GET | `/users/{userId}` | ユーザー詳細 |
| GET | `/users/{userId}/answers` | ユーザーの回答ログ一覧 |

### Publish

| Method | Path | 説明 |
|--------|------|------|
| POST | `/publish` | DB の内容を S3 に静的 JSON として書き出す |

`/publish` を叩くまでコンテンツ CDN の内容は変わらない。さらに問題集 Web は
ビルド時に JSON を焼き込むため、web にも反映したい場合は publish 後に web を
再デプロイする。詳細は [データ同期](datasync.md) と [runbook](runbook.md)。

### Images

| Method | Path | 説明 |
|--------|------|------|
| POST | `/images/presigned-url` | 画像アップロード用 Presigned URL 発行 |

## データモデル

### リクエスト

**CreateQuestion / UpdateQuestion:**

```json
{
  "type": "single_choice",
  "text": "問題文",
  "choices": [
    {"text": "選択肢A", "isCorrect": true},
    {"text": "選択肢B", "isCorrect": false}
  ],
  "explanation": "解説（任意）",
  "imageIds": [1, 2]
}
```

- `choices` は2個以上必須
- `isCorrect: true` の選択肢が1つ以上必須

**CreateWorkbook / UpdateWorkbook:**

```json
{
  "title": "問題集名",
  "description": "説明（任意）",
  "questionIds": [1, 2, 3]
}
```

- `questionIds` は順序を保持（`order_index`として保存）

**CreatePresignedUrl:**

```json
{
  "filename": "photo.png",
  "contentType": "image/png"
}
```

- `contentType`: `image/png` または `image/jpeg`

### レスポンス

| 操作 | ステータス | 内容 |
|------|-----------|------|
| GET (一覧) | 200 | リソース配列 + total |
| GET (詳細) | 200 | リソース |
| POST | 201 | 作成したリソース |
| PUT | 200 | 更新したリソース |
| DELETE | 204 | No Content |
| Presigned URL | 200 | `{uploadUrl, imageId, cdnUrl}` |

公開APIとの違い: 管理APIの `choices` は `{text, isCorrect}` オブジェクト配列を返す（公開APIは文字列配列）。

## 環境変数

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `DATABASE_URL` | PostgreSQL接続文字列 | `postgres://rikako:password@localhost:5432/rikako?sslmode=disable` |
| `IMAGE_BASE_URL` | 画像CDNのベースURL | `https://example.com` |
| `IMAGE_S3_BUCKET` | 画像用 S3 バケット名（Presigned URL 用） | （未設定時は Presigned URL 無効） |
| `CONTENT_S3_BUCKET` | コンテンツ用 S3 バケット名（`/publish` の書き出し先） | （未設定時は `/publish` 無効） |
| `DB_USE_POOLER` | `true` なら Neon の pooled endpoint に接続する | （未設定 = direct） |
| `PORT` | リッスンポート | `8081` |

Lambda では `DATABASE_URL` などに `ssm:/rikako/<env>/...` の参照が入り、起動時に
`app/internal/secrets.Resolve` が実値へ展開する。

## アーキテクチャ

```mermaid
graph TB
    Admin[管理画面] -->|CRUD| AdminAPI["Admin API<br/>:8081"]
    AdminAPI --> DB[(PostgreSQL)]
    AdminAPI -->|Presigned URL| S3["S3 画像"]
    AdminAPI -->|"POST /publish"| ContentS3["S3 コンテンツ"]
    Admin -->|Presigned URL で直接アップロード| S3
    S3 --> CF["image.rikako.org"]
    ContentS3 --> ContentCF["content.rikako.org"]
```

## ローカル開発

```bash
# PostgreSQL起動
docker compose up -d

# 管理APIサーバー起動
cd app && go run ./cmd/admin

# テスト
cd app && go test ./internal/admin/ -v

# APIコード再生成（openapi-admin.yaml変更時）
cd app && oapi-codegen --config oapi-codegen-admin.yaml ../openapi-admin.yaml
```

## 画像アップロードフロー

```mermaid
sequenceDiagram
    participant Client as Admin Client
    participant API as Admin API
    participant DB as PostgreSQL
    participant S3 as S3

    Client->>API: POST /images/presigned-url
    API->>DB: INSERT INTO images (path)
    DB-->>API: imageId
    API->>S3: Generate Presigned PUT URL
    S3-->>API: presigned URL
    API-->>Client: {uploadUrl, imageId, cdnUrl}
    Client->>S3: PUT (upload image)
    Client->>API: POST /questions (with imageIds)
    API->>DB: INSERT question + question_images
```

## 今後の予定

- 認証の追加（Cognito or API Key）
- `admin-api.dev.rikako.jp` でのデプロイ（#77 完了後）
- Lambda + CloudFront でのホスティング
