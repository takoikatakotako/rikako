# web — 問題集 Web

過去問を解く学習用 Web。**1 つのコードベースを `NEXT_PUBLIC_SITE` で出し分けて**
2 サイトを配信している。

| サイト | dev | prod |
|--------|-----|------|
| `it`（ITパスポート） | https://it.dev.rikako.org/ | https://it.rikako.org/ |
| `chemistry`（化学） | https://chemistry.dev.rikako.org/ | https://chemistry.rikako.org/ |

Next.js 16（App Router / 静的 export）。S3 + CloudFront で配信する。dev は Basic 認証あり。

**問題データはビルド時に焼き込む。** コンテンツ CDN（`NEXT_PUBLIC_CONTENT_BASE_URL`）から
取得した JSON を静的エクスポートに埋め込むため、公開内容を変えたら管理 API の `/publish`
を実行したうえで **web を再デプロイする**必要がある。

## ビルド時の環境変数（NEXT_PUBLIC_*）

| 変数 | 用途 |
|------|------|
| `NEXT_PUBLIC_SITE` | `it` / `chemistry` の出し分け |
| `NEXT_PUBLIC_CONTENT_BASE_URL` | コンテンツ CDN（問題データの取得元） |
| `NEXT_PUBLIC_API_BASE_URL` | 公開 API |
| `NEXT_PUBLIC_COGNITO_REGION` | Cognito のリージョン |
| `NEXT_PUBLIC_COGNITO_CLIENT_ID` | Cognito App Client ID |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | GA4 の測定 ID |

dev / prod の実際の値はデプロイワークフローに直接書いてある。**取り違えると本番サイトが
dev に書き込むなどの事故になるため、`scripts/check-frontend-env.py` が CI で値を検証する。**
値を変えるときはこのスクリプトの `EXPECTED` も更新すること。

## コマンド

```bash
npm install
NEXT_PUBLIC_SITE=chemistry npm run dev   # ローカル確認
npm run build                             # 静的 export（out/）
npm run lint
npm run test
```

## 関連ドキュメント

- [アーキテクチャ](../docs/architecture.md)
- [運用ランブック](../docs/runbook.md)
