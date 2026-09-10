# portal — rikako.org アカウントポータル

Rikako のアカウント（ログイン・新規登録・パスワード再設定）Web。Cognito User Pool を
Amplify 非依存で直叩きし（`src/lib/cognito.ts`）、ID/Access/Refresh token を localStorage
に保持する（`src/lib/tokens.ts`、rikako.org のみ・跨ぎ SSO なし）。

Next.js 16（App Router / 静的 export、S3+CloudFront 配信想定）。

## ビルド時の環境変数（NEXT_PUBLIC_*）

| 変数 | 例 | 用途 |
|------|----|------|
| `NEXT_PUBLIC_COGNITO_REGION` | `ap-northeast-1` | cognito-idp のリージョン |
| `NEXT_PUBLIC_COGNITO_CLIENT_ID` | App Client ID | SignUp/InitiateAuth の ClientId |
| `NEXT_PUBLIC_API_BASE_URL` | `https://api.rikako.org` | 公開 API（`/account/link`・`/account/services`）|
| `NEXT_PUBLIC_PORTAL_URL` | `https://account.dev.rikako.org` | metadataBase（配信ドメイン。環境別）|

## コマンド

```bash
npm install
npm run dev     # ローカル確認
npm run build   # 静的 export（out/）
npm run lint
```

## 配信先

| | URL |
|---|---|
| dev | https://account.dev.rikako.org/（Basic 認証あり） |
| prod | https://account.rikako.org/ |

Terraform（`portal_frontend.tf`）とデプロイワークフロー（`deploy-portal-{dev,prod}.yml`）
とも整備済み。apex の `rikako.org` は LP を残すため、ポータルは `account.` サブドメインに置いている。

## 実装済みの機能（#283）

- 新規登録 → メール確認コード → ログイン → ログアウト
- パスワード再設定
- ログイン後の `POST /account/link`（匿名で貯めた学習記録をアカウントへ引き継ぐ）
- 利用中サービス（アプリ）一覧の表示
