# 管理画面 (Admin Frontend)

問題・問題集・カテゴリを管理するためのWebフロントエンド。

## 概要

| 項目 | 値 |
|------|-----|
| フレームワーク | Next.js 16 (App Router, static export) |
| ソースコード | `admin/` |
| デプロイ先 | S3 + CloudFront（Basic Auth） |
| Dev URL | https://admin.dev.rikako.org/ |
| Prod URL | https://admin.rikako.org/ |

## ページ一覧

`categories` / `workbooks` / `questions` / `users` / `announcements` は
`[[...slug]]` の catch-all ページ 1 枚で、クライアント側のルーター
（`components/<resource>/<resource>-router.tsx`）が一覧・作成・詳細・編集を出し分ける。
静的エクスポートなので、ID ごとの HTML は生成していない。

| リソース | 一覧 | 作成 | 詳細 | 編集 |
|----------|------|------|------|------|
| カテゴリ | `/categories` | `/categories/new` | `/categories/{id}` | `/categories/{id}/edit` |
| 問題集 | `/workbooks` | `/workbooks/new` | `/workbooks/{id}` | `/workbooks/{id}/edit` |
| 問題 | `/questions` | `/questions/new` | `/questions/{id}` | `/questions/{id}/edit` |
| お知らせ | `/announcements` | `/announcements/new` | `/announcements/{id}` | `/announcements/{id}/edit` |
| ユーザー | `/users` | — | `/users/{id}` | —（参照のみ） |

### 単独ページ

| パス | 説明 |
|------|------|
| `/` | `/categories` へリダイレクト |
| `/apps` | アプリ（flavor）ごとの設定 |
| `/app-status` | アプリステータス（メンテナンス表示など） |

## コンテンツの公開

問題や問題集を編集しても、それだけでは配信されない。管理 API の `POST /api/publish` を
叩くと DB の内容が S3 に静的 JSON として書き出され、コンテンツ CDN が配信する。
問題集 Web はビルド時にその JSON を焼き込むため、web にも反映したい場合は publish 後に
web を再デプロイする。詳細は [管理API設計](admin-api.md) と [runbook](runbook.md)。
