# 負荷テスト

[k6](https://k6.io/) を使った Rikako 公開 API の負荷テスト一式。テスト計画は [docs/load-test.md](../docs/load-test.md) を参照。

## セットアップ

```bash
brew install k6
```

## 実行

各シナリオは `scenarios/` 配下にある。

```bash
# ベースライン（/health に 10 RPS × 5 分）
k6 run scenarios/baseline.js

# POST /answers（Neon に書き込み、デフォルト 20 RPS × 2 分）
k6 run scenarios/answers.js

# RPS と継続時間を変えて流す（例: 50 RPS × 5 分）
RATE=50 DURATION=5m k6 run scenarios/answers.js

# スパイク（0 → 100 RPS を 30 秒で立ち上げ、2 分維持）
k6 run scenarios/spike.js
```

### 環境変数

| 変数 | デフォルト | 用途 |
|---|---|---|
| `API_BASE_URL` | `https://api.dev.rikako.org` | 公開 API のベース URL |
| `CONTENT_BASE_URL` | `https://content.dev.rikako.org/v1` | コンテンツ JSON のベース URL（setup で使用） |
| `WORKBOOK_ID` | `3` | 負荷をかける workbookId（令和7年度 ITパスポート） |
| `RATE` | `20`（answers のみ） | 1 秒あたりのリクエスト数 |
| `DURATION` | `2m`（answers のみ） | テスト継続時間 |
| `TARGET_RATE` | `100`（spike のみ） | ピーク時の RPS |
| `RAMP_DURATION` | `30s`（spike のみ） | 0 → `TARGET_RATE` に到達するまでの時間 |
| `SUSTAIN_DURATION` | `2m`（spike のみ） | ピーク RPS を維持する時間 |
| `ANSWERS_PER_REQUEST` | `3`（answers / spike） | 1 リクエストに含める解答数 |

例: ローカル API に対して実行する場合

```bash
API_BASE_URL=http://localhost:8080 k6 run scenarios/baseline.js
```

## 結果の保存

`results/` ディレクトリは gitignore 済み。必要なら以下のように JSON 出力できる:

```bash
k6 run --out json=results/baseline-$(date +%Y%m%d-%H%M%S).json scenarios/baseline.js
```
