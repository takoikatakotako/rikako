# Android アプリ

`android/` に置いた Kotlin + Jetpack Compose のアプリ。問題データは iOS と同じく
Content CDN（S3 + CloudFront の静的 JSON）から取得する。

## 構成

| 項目 | 値 |
| --- | --- |
| 言語 / UI | Kotlin 2.1 + Jetpack Compose (Material 3) |
| ビルド | Gradle 8.11.1 + AGP 8.7.3 |
| SDK | compileSdk / targetSdk 35、minSdk 26 |
| 通信 | Ktor Client (OkHttp) + kotlinx.serialization |
| 画像 | Coil 3（設問画像の読み込み） |
| 画面遷移 | navigation-compose |

```
android/
├── gradle/libs.versions.toml     # 依存バージョンカタログ
└── app/src/
    ├── main/kotlin/org/rikako/quiz/
    │   ├── AppFlavor.kt          # BuildConfig 経由でフレーバー設定を読む
    │   ├── ServiceLocator.kt     # DI ライブラリ導入までの簡易依存解決
    │   ├── MainActivity.kt       # NavHost（問題集一覧 → 詳細 → 解答）
    │   ├── RikakoApplication.kt  # ServiceLocator の初期化
    │   ├── data/model            # JSON のモデル（iOS の Domain/Entity 相当）
    │   ├── data/remote           # ContentApi / AnswerApi / CognitoIdentityApi
    │   ├── data/identity         # 匿名 identity の払い出しと保存
    │   ├── data/repository       # LearningRepository
    │   └── ui/                   # theme / workbook / quiz 画面
    ├── chemistry/res             # 化学版のリソース（アプリ名など）
    └── itPassport/res            # IT 版のリソース
```

## ビルド変種

iOS の xcconfig と同じ軸を productFlavors の 2 ディメンションで表現する。

| ディメンション | フレーバー | 内容 |
| --- | --- | --- |
| `app` | `chemistry` / `itPassport` | アプリの種類。applicationId は `org.rikako.chemistry` / `org.rikako.itpassport` |
| `env` | `dev` / `prod` | 接続先。`dev` は applicationId に `.dev` が付く |

接続先とアプリ種別は `buildConfigField` で渡し、`AppFlavor.current` から参照する。

```bash
cd android

# 化学版 dev をビルド
./gradlew :app:assembleChemistryDevDebug

# ユニットテスト
./gradlew :app:testChemistryDevDebugUnitTest

# 端末にインストール
./gradlew :app:installChemistryDevDebug
```

`local.properties`（`sdk.dir`）は各自の環境で生成する。Android Studio で `android/` を開けば自動生成される。

## データ取得

- 問題集一覧: `GET {CONTENT_BASE_URL}/workbooks.json`
- 問題集詳細: `GET {CONTENT_BASE_URL}/workbooks/{id}.json`
- フレーバーが扱うカテゴリ: `GET {API_BASE_URL}/apps/{slug}`

一覧は取得後に「そのフレーバーのカテゴリに属する問題集」だけへ絞り込む（iOS の
`RemoteLearningRepository` と同じ挙動）。

## 匿名認証

普段は匿名で使い、機種変更時にログインして引き継ぐ方針は iOS と同じ。Android も
Cognito Identity Pool の `GetId` を直接叩いて identity ID を払い出す（未認証 identity の
`GetId` は署名不要なので AWS SDK は入れていない）。

- 払い出した ID は `SharedPrefsIdentityStore`（アプリ専用の SharedPreferences）に保存する
  — iOS の Keychain と同じ位置づけ
- サーバーへは `X-Device-ID` ヘッダーで送る
- `rotate()` は保存済みの ID を捨てて取り直す。`GetId` は logins 無しだと毎回新しい
  identity を払い出すため、これだけでローテーションになる

## 解答フロー

問題集一覧 →（詳細）→ 解答 → 結果、の順に進む。

1. `QuizScreen` が `workbooks/{id}.json` を読み、1問ずつ出題する
2. 選択肢を選んだ時点で正誤と解説を表示し、変更はできない（iOS の `QuizViewModel` と同じ）
3. 最後の問題を終えると結果を表示し、`POST /answers` を送信する
4. 送信は `ServiceLocator.applicationScope` で実行するため、結果画面を閉じても最後まで走る
5. 送信に失敗しても結果は表示したままにするが、**再送ボタンは出さない** —
   `POST /answers` に冪等化が無く、レスポンスだけ失われたケースで再送すると
   回答と集計が二重計上されるため（[#377](https://github.com/takoikatakotako/rikako/issues/377)）

採点は `QuizScoring` に純粋関数として置いてある（サーバーも同じ判定をするが、
結果表示を送信の成否に依存させないため）。未回答の問題は送信対象に含めない。

解答中に戻ると記録が消えるため、回答が1件でもあるときは iOS と同じ確認ダイアログを出す
（ツールバーの戻るとシステム Back の両方）。「履歴を保存して戻る」は送信の完了を待たずに
画面を閉じる — 送信自体は applicationScope で完走するので、送信中に画面が操作できたり
二重送信になったりしない。

## CI

`.github/workflows/android.yml` が `android/**` の変更で走る（main への push と PR）。

1. `gradle/actions/wrapper-validation` で `gradle-wrapper.jar` を検証
2. `:app:testChemistryDevDebugUnitTest`（ユニットテスト）
3. `:app:lintChemistryDevDebug`（Android Lint）
4. `:app:assembleChemistryDevDebug` / `:app:assembleItPassportDevDebug`
   （フレーバーごとにリソースが別ディレクトリなので両方ビルドする）
5. `:app:assembleChemistryProdRelease`（R8 の縮小はリリースビルドでしか走らないため）

失敗時は `android/app/build/reports/` をアーティファクトとして残す。

## 未実装

一覧・詳細・解答フローまで実装済み。以下は今後追加する。

- メールログイン（`COGNITO_CLIENT_ID` は BuildConfig に用意済み）
- 学習記録・間違えた問題の一覧
- ランチャーアイコン（現状はプレースホルダーのベクター画像）
- デプロイ（Play Console へのアップロード）
