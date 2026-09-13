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
| 画面遷移 | navigation-compose |

```
android/
├── gradle/libs.versions.toml     # 依存バージョンカタログ
└── app/src/
    ├── main/kotlin/org/rikako/quiz/
    │   ├── AppFlavor.kt          # BuildConfig 経由でフレーバー設定を読む
    │   ├── ServiceLocator.kt     # DI ライブラリ導入までの簡易依存解決
    │   ├── MainActivity.kt       # NavHost（問題集一覧 → 詳細）
    │   ├── data/model            # JSON のモデル（iOS の Domain/Entity 相当）
    │   ├── data/remote           # ContentApi（content CDN + 公開 API）
    │   ├── data/repository       # LearningRepository
    │   └── ui/                   # theme / workbook 画面
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

雛形の時点では一覧と詳細表示のみ。以下は今後追加する。

- 解答フロー（`POST /answers`）と結果画面
- Cognito 匿名認証 / メールログイン（`COGNITO_*` の値は BuildConfig に用意済み）
- ランチャーアイコン（現状はプレースホルダーのベクター画像）
- デプロイ（Play Console へのアップロード）
