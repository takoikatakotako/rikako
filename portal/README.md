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
| `NEXT_PUBLIC_API_BASE_URL` | `https://api.rikako.org` | API（/account/link 等、後続 PR で使用）|
| `NEXT_PUBLIC_PORTAL_URL` | `https://account.dev.rikako.org` | metadataBase（配信ドメイン。環境別）|

## コマンド

```bash
npm install
npm run dev     # ローカル確認
npm run build   # 静的 export（out/）
npm run lint
```

## 現状（Phase 3 の一部・#283）

- 実装済み: 新規登録 → メール確認コード → ログイン → ログアウト、パスワード再設定。
- 未実装（後続 PR）: ログイン後の `/account/link` 呼び出し、プロフィール/利用中サービス表示、
  Terraform（apex rikako.org の S3+CloudFront）・デプロイワークフロー。
