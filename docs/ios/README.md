# iOS Docs

`ios/Rikako` の設計メモと画面仕様の入口です。

## まず読むもの

- [architecture.md](./architecture.md)
  - ディレクトリ構成、責務、依存方向
- [navigation.md](./navigation.md)
  - `RootView` からの画面遷移
- [onboarding.md](./onboarding.md)
  - オンボーディングの画面仕様

## ドキュメントの見方

- 全体の構成を知りたいとき
  - [architecture.md](./architecture.md)
- どの画面にどう遷移するかを見たいとき
  - [navigation.md](./navigation.md)
- オンボーディングの文言や画面意図を見たいとき
  - [onboarding.md](./onboarding.md)

## 現在の前提

- 画面構成は `Screen -> ViewModel -> UseCase -> Repository -> Infrastructure`
- 画面横断状態は `AppState`
- 問題系の取得は実 API / 実 JSON
- 学習記録やお知らせなどは一部仮実装

詳細は各ドキュメントを参照してください。

## 画像生成

- オンボーディング画像の生成: `swift scripts/render_onboarding.swift`
- 出力先: `docs/ios/images/onboarding/`
