# Rikako

問題集アプリのドキュメントです。iOS アプリ・4 種類の Web・公開/管理 API・問題データが
1 つのリポジトリに同居しています。

## はじめに読むもの

- [アーキテクチャ](architecture.md) — 全体構成、データの流れ、認証、デプロイ、監視

## 設計

- [問題形式仕様書](question-types.md) — 対応する問題形式と DB 設計
- [メールログイン設計](email-login-design.md) — 匿名利用とログインの併存、データ引き継ぎ
- [管理API設計](admin-api.md) — 管理 API の設計と仕様
- [管理画面](admin-frontend.md) — 管理画面フロントエンドの画面一覧
- [iOSアプリ](ios.md) — 画面遷移、計測

## API リファレンス

- [公開API](api/index.html) — OpenAPI から生成（Swagger UI）
- [管理API](admin-api/index.html) — 同上

## 開発

- [AWS CLI セットアップ](aws-setup.md) — SSO プロファイルの設定
- [データ同期 (datasync)](datasync.md) — YAML ↔ DB の差分確認・反映
- [sqlc（DBクエリ生成）](sqlc.md) — SQL から型安全な Go コードを生成

## 運用

- [運用ランブック](runbook.md) — デプロイ・ロールバック・障害対応
- [DBバックアップとリストア](db-backup.md)
- [負荷テスト計画](load-test.md)

## その他

- [DBスキーマ](schema/README.md) — tbls が DB から自動生成
- [プライバシーポリシー](privacy.md)
