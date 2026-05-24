# 負荷テスト計画

Lambda + Neon 構成のサーバーレス API がどの程度のトラフィックを捌けるかを把握し、リリース前にボトルネックを特定する。Issue [#39](https://github.com/takoikatakotako/rikako/issues/39) に対応する。

## 対象範囲

### 対象
公開 API のうち、Lambda + Neon を経由するエンドポイント。

| メソッド | パス | 内容 | 認証 |
|---|---|---|---|
| POST | `/answers` | 解答送信（書き込み） | 不要 |
| GET | `/users/me/wrong-answers` | 間違えた問題一覧 | 不要 |
| GET | `/health` | ヘルスチェック（ベースライン） | 不要 |

### 対象外
- 問題集／問題詳細の取得：CloudFront + S3 で静的 JSON 配信のため、Lambda 負荷とは無関係
- 管理 API：内部利用のみで負荷想定なし

## 観測指標

| 指標 | 取得元 | 合格目安 |
|---|---|---|
| p50 レイテンシ | k6 / CloudWatch | 200ms 以下 |
| p95 レイテンシ | k6 / CloudWatch | 500ms 以下 |
| p99 レイテンシ | k6 / CloudWatch | 1s 以下 |
| エラー率（5xx） | k6 / CloudWatch | 0.1% 以下 |
| Cold start レイテンシ | CloudWatch (Init Duration) | 計測のみ（参考値） |
| Lambda 同時実行数 | CloudWatch (ConcurrentExecutions) | アカウント上限 1000 に対し余裕 |
| Neon コネクション数 | Neon Console | プール枯渇しないこと |

## シナリオ

### 1. ベースライン
- 10 RPS × 5 分
- 目的: warm 状態の素の応答時間を把握

### 2. スパイク
- 0 → 100 RPS を 30 秒で立ち上げ → 2 分維持
- 目的: cold start が大量発生する状況での挙動確認

### 3. サステイン
- 50 RPS × 10 分
- 目的: Neon コネクションプールの安定性、メモリリーク有無

### 4. 限界探索
- 段階的に RPS を上昇（10 → 50 → 100 → 200 → ...）
- 5xx 発生または p95 > 1s で打ち切り
- 目的: 現構成の上限値を確定

## ツール

**k6** を採用。

- JavaScript でシナリオ記述、学習コスト低
- ローカル実行で十分（Rikako 想定 RPS では分散実行不要）
- 結果を JSON / CloudWatch / Grafana に出力可能

Artillery は YAML で書きやすいが分散実行が有料、Locust は Python 製で柔軟だがシナリオの記述量が多いため見送り。

## 環境

- **対象環境**: dev（`https://api.dev.rikako.org`）
- **Neon CU**: 0.25〜2 CU（dev デフォルト）
- **Lambda メモリ**: 現行設定のまま（変更時は別途記録）
- **実行マシン**: 開発者ローカル（必要なら EC2 から）

## 事前準備

- [ ] テスト用 Cognito Identity 取得手順を整理（匿名認証）
- [ ] `X-Device-ID` ヘッダ用の Identity ID を複数払い出してシナリオで使い回す
- [ ] dev 環境に十分な問題データが投入されている前提を確認

## 実施手順

1. `load-test/` ディレクトリ作成、k6 シナリオを配置
2. 各シナリオを順次実行、結果を `load-test/results/` に保存
3. CloudWatch メトリクスと突き合わせて記録
4. ボトルネック分析、対策案を本ドキュメントに追記
5. 必要に応じて Lambda メモリ／Neon CU を調整して再実行

## 結果記録

実施後に追記する。

| 実施日 | シナリオ | p95 | エラー率 | 備考 |
|---|---|---|---|---|
| - | - | - | - | - |
