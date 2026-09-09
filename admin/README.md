# admin — 管理画面

問題・問題集・カテゴリ・お知らせ・ユーザーを管理する社内向け Web。

| | URL |
|---|---|
| dev | https://admin.dev.rikako.org/ |
| prod | https://admin.rikako.org/ |

Next.js 16（App Router / 静的 export）。S3 + CloudFront で配信し、**dev / prod とも
CloudFront Function の Basic 認証**で保護している。同じディストリビューションの `/api`
配下が管理 API（Lambda Function URL）。

静的エクスポートのため ID ごとの HTML は生成せず、`[[...slug]]` の catch-all ページと
クライアント側ルーターで一覧・作成・詳細・編集を出し分ける。

## ビルド時の環境変数（NEXT_PUBLIC_*）

| 変数 | 用途 |
|------|------|
| `NEXT_PUBLIC_ADMIN_API_URL` | 管理 API のベース URL（`/api`） |
| `NEXT_PUBLIC_APP_ENV` | `development` / `production` |

## コマンド

```bash
npm install
npm run dev     # ローカル確認（http://localhost:3000）
npm run build   # 静的 export（out/）
npm run lint
```

ローカルで管理 API を動かす場合は `cd app && go run ./cmd/admin`（ポート 8081）。

## 関連ドキュメント

- [管理画面の画面一覧](../docs/admin-frontend.md)
- [管理API設計](../docs/admin-api.md)
