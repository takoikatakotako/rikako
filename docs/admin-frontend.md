# 管理画面 (Admin Frontend)

問題・問題集・カテゴリを管理するためのWebフロントエンド。

## 概要

| 項目 | 値 |
|------|-----|
| フレームワーク | Next.js 15 (App Router, static export) |
| ソースコード | `admin/` |
| デプロイ先 | S3 + CloudFront |
| Dev URL | https://admin.dev.rikako.jp |

## ページ一覧

### カテゴリ

| パス | 説明 |
|------|------|
| `/categories` | カテゴリ一覧 |
| `/categories/new` | カテゴリ作成 |
| `/categories/{id}` | カテゴリ詳細（紐付き問題集一覧を含む） |
| `/categories/{id}/edit` | カテゴリ編集 |

### 問題集

| パス | 説明 |
|------|------|
| `/workbooks` | 問題集一覧 |
| `/workbooks/new` | 問題集作成 |
| `/workbooks/{id}` | 問題集詳細（紐付き問題一覧を含む） |
| `/workbooks/{id}/edit` | 問題集編集 |

### 問題

| パス | 説明 |
|------|------|
| `/questions` | 問題一覧 |
| `/questions/new` | 問題作成 |
| `/questions/{id}` | 問題詳細 |
| `/questions/{id}/edit` | 問題編集 |

### その他

| パス | 説明 |
|------|------|
| `/` | `/categories` にリダイレクト |
