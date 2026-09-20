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
| 画像 | Coil 3（設問画像の読み込み）、iOS と共通のマスコット・結果イラスト |
| QR | ZXing（生成・保存画像の読取）、Google Code Scanner（カメラスキャン） |
| 画面遷移 | navigation-compose |

```
android/
├── gradle/libs.versions.toml     # 依存バージョンカタログ
└── app/src/
    ├── main/kotlin/org/rikako/quiz/
    │   ├── AppFlavor.kt          # BuildConfig 経由でフレーバー設定を読む
    │   ├── ServiceLocator.kt     # DI ライブラリ導入までの簡易依存解決
    │   ├── MainActivity.kt       # 初期設定と3タブの NavHost
    │   ├── RikakoApplication.kt  # ServiceLocator の初期化
    │   ├── data/model            # JSON のモデル（iOS の Domain/Entity 相当）
    │   ├── data/remote           # ContentApi / AnswerApi / UserApi / Cognito 系 / AccountApi
    │   ├── data/identity         # 匿名 identity の払い出しと保存
    │   ├── data/auth             # メールログインのセッションとトークン保存
    │   ├── data/repository       # LearningRepository
    │   └── ui/                   # onboarding / workbook / quiz / chat / record / mypage など
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

## メールログイン

普段は匿名のまま使い、機種変更時にログインして引き継ぐ方針。iOS の `AccountSession` と同じ作りにしてある。

- `CognitoUserPoolApi` が cognito-idp を直接叩く（SignUp / ConfirmSignUp / ResendConfirmationCode /
  InitiateAuth（USER_PASSWORD_AUTH・REFRESH_TOKEN_AUTH）/ ForgotPassword / ConfirmForgotPassword / RevokeToken）。
  エラーコードの日本語文言は iOS の `CognitoError` と `portal/src/lib/cognito.ts` に合わせている
- トークンは **Android Keystore の鍵で暗号化**して保存する（`KeystoreAuthTokenStore`）。
  refresh token は再利用可能な認証情報なので平文で置かない。鍵は Keystore から取り出せないため、
  バックアップが端末外へ出ても復号できない。加えて `rikako_auth` / `rikako_identity` の
  SharedPreferences はクラウドバックアップと端末間転送から除外している（`res/xml/*.xml`）。
  iOS の Keychain `AfterFirstUnlockThisDeviceOnly` と同じ位置づけ。
  秘密情報でない `linkPending` は別の prefs に置く
- `AccountSession.validIdToken()` は期限が近ければ refresh する。refresh の失敗は
  **terminal（refresh token 失効）と transient（オフライン等）を区別**し、どちらも throw する。
  terminal でもローカルを消したうえで throw するのが要点で、null を返すと期限切れを検知した
  その1回の書き込みだけが匿名側へ流れてしまう
- ログイン中は API 呼び出しに `Authorization: Bearer <ID token>` を付ける（サーバーはアカウント側の
  ユーザーを読み書きする）。`X-Device-ID` は常に送る
- ログイン直後とアプリ起動時に `POST /account/link` を実行して匿名データを引き継ぐ。成功するまで
  pending を残すので、通信エラーで失敗しても次回起動でやり直せる。409（この端末が別アカウントに
  紐付き済み）のときは匿名 identity を取り直して再試行する
- ログイン中の API 呼び出しは `AuthorizedCall` を通す。**401 のときだけ**期限を見ずに refresh して
  1回だけ再送し、それでも 401 ならセッションを終了する（再試行しないと、端末の時計では有効なのに
  以後の取得・送信が失敗し続ける）。再試行は**開始時のセッションに束縛**する。通信中にログアウト →
  別アカウントでログインした場合に、古いリクエストの 401 で新しいアカウントのトークンを refresh したり、
  同じ操作を別アカウントとして再送したりしないため
- メール未確認のままログインすると `UserNotConfirmedException` になるので、確認コード入力へ誘導する
  （iOS / portal と同じ。ここが無いと、再ログインも再登録もできずアカウントを確認できなくなる）
- `/account/link` の進行状況は `AccountRepository.linkState` に出す。起動時の再試行結果も
  アカウント画面から見えて、その場で再試行できる。`ensureLinked` は専用 mutex で **1本ずつ**
  実行し、pending の判定と更新もその中で行う（起動時とログイン直後の2呼び出しが並行すると、
  片方の成功で pending が落ちた後にもう片方の失敗が残り、再試行もできなくなる）。
  pending を下げるのは**開始時と同じセッションのときだけ**で、世代の確認と pending の更新は
  `AccountSession.ifSameSession` でセッション遷移と同じロックにまとめる（分けると、確認の直後に
  ログアウト → 別アカウントでログインした場合に新しいセッションの pending を下げてしまう）
- 世代と ID token は `AccountSession.currentToken()` が同じロックの中で組にして返す
  （別々に読むと、その間にセッションが変わって食い違った組を API 呼び出しに渡してしまう）
- トークンの保存に失敗したらインメモリも更新せず、ログイン自体を失敗させる。保存できていないのに
  ログイン済みにすると、その場は動くのに再起動で突然ログアウトする。鍵が壊れている場合に備えて、
  保存時に1度だけ鍵を作り直してからやり直す
- `signIn` / `signOut` / refresh は同じ mutex と世代番号で直列化する。これが無いと、
  refresh の通信中にログアウトしたときに clear → refresh 成功 → apply の順になり、
  ログアウト後もトークンが復活してしまう
- 回答送信と link は `SubmissionGate` で直列化する。link は匿名ユーザーの回答をアカウントへ
  移す操作なので、送信と重なると移動後の旧ユーザーへ INSERT が入り、その回答だけ取り残される

## 間違えた問題の解き直し

「学習記録」から開く「間違えた問題」の「まとめて解き直す」と、結果画面の「間違えた問題を解き直す」から、
間違えた問題だけを出題する。一度の復習は iOS と同じく最大50問。

出題元は `QuizSource` で表す（iOS と同じ考え方）。

- `Workbook`: 通常プレイ。全問が同じ問題集
- `Review`: 解き直し。問題ごとに出身の問題集が違うため、問題ID → 問題集ID の対応を持つ

回答の送信は `QuizSource.groupedAnswers` で**問題集ごとにまとめてから** `POST /answers` を
呼ぶ。解き直しでも、回答は元の問題集の記録として残る。

## 解答フロー

学習ホーム（問題集選択とチャプター一覧）→ 解答 → 結果、の順に進む。

学習ホームは選択中の問題集を端末に保持し、`PUT /users/me` でサーバーとも同期する。`GET /users/me/workbook-progress?workbook_id=...`
で各チャプターの正解数を表示する。回答が送信されると進捗を再取得する。

1. 問題集は iOS と同じく10問ずつのチャプターに分け、`QuizScreen` が指定チャプターを1問ずつ出題する
2. 選択肢を選んだ時点で正誤と解説を表示し、変更はできない（iOS の `QuizViewModel` と同じ）
3. 最後の問題を終えると結果を表示し、`POST /answers` を送信する。結果から次のチャプターへ進める
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

## 画面構成

ボトムナビゲーションは iOS と同じ3タブ。解答中はタブを出さない（誤操作で回答が失われるため）。

| タブ | 画面 | データ |
| --- | --- | --- |
| 学習 | 問題集選択 → チャプター → 解答 → 結果 | content CDN + `GET /apps/{slug}` + 問題集進捗 API |
| 学習記録 | サマリーと回答履歴。間違えた問題の復習へ進める | `GET /users/me/summary`、`GET /users/me/answer-logs`、`GET /users/me/wrong-answers` |
| マイページ | プロフィール・設定・お知らせ・FAQ/お問い合わせ。設定からアカウントへ進める | `GET/PUT /users/me`、content CDN の `announcements.json`、`POST /contact` |

初回は6ページのオンボーディングで教材選択と利用規約への同意を行い、匿名IDを払い出す。
「初期設定をやり直す」では教材選択だけを消し、匿名ID・学習記録・ログイン状態は残す。
AI質問は解答後と結果詳細から開ける。問題ID・選択した回答・会話履歴を `POST /questions/{id}/chat`
へ送り、1問につき最大5往復までに制限する。

回答履歴と間違えた問題は20件ずつのページング（末尾が見えたら次ページを取得）。ページ境界で
新しい回答が入って同じ項目が二度並ぶことがあるので、id で重複を弾いてから連結する。
このとき **offset は表示件数ではなくサーバーから受け取った件数で進める**（重複除外後の件数を
使うと毎回1件ずつ重なり、終端に到達できなくなる）。

回答が送信されると `LearningRepository.learningDataChanged` が流れ、学習記録・間違えた問題の
両画面が読み直す。タブを開いたまま問題を解いても古い集計が残らないようにするため。
読み込みには世代番号を持たせ、**開始時と一致する応答だけ適用する**（進行中の次ページ取得が
再読込後の状態へ連結されると、その分の offset が飛ばされて表示が欠ける）。

回答日時（`answeredAt`）は RFC3339 の絶対時刻で UTC で返るので、Asia/Tokyo に変換してから
日付にする。文字列の日付部分をそのまま使うと JST の 0:00〜8:59 の回答が前日になり、
サーバー側で Asia/Tokyo 換算している `studyDates` と食い違う。

## アイコン

ランチャーアイコンは iOS と同じ絵柄の 512px PNG をアプリ・環境ごとに用意する。
開発版は Dev バッジ付き、本番版はバッジ無し。アダプティブアイコンの前景は
`ic_launcher_art_inset.xml` で表示領域に収め、Android 13 以降のテーマアイコンには
共通の `ic_launcher_monochrome.xml` を使う。

## アプリの最低バージョン

Android の `GET /status` は `X-App-Slug` に加えて `X-App-Platform: android` を送る。
API は `MINIMUM_VERSION_ANDROID` / `LATEST_VERSION_ANDROID` を返し、
`MINIMUM_VERSION_ANDROID_HIGH_SCHOOL_CHEMISTRY` のようなアプリ別 env で上書きできる。
プラットフォームヘッダのない既存 iOS クライアントには従来の設定を返す。
Android を公開する前に API と Terraform の変更を適用し、iOS の最低バージョン変更が
Android へ波及しないことを確認する。

## Play Console へのデプロイ

`.github/workflows/deploy-android-prod.yml` を手動起動する（flavor / track / draft を選ぶ）。
main からの起動に限定し、`environment: production` の承認を通してからアップロードする。

手動の初回 AAB は `ANDROID_VERSION_CODE=1` でビルドする。以後 CI は
2020-01-01 UTC からの経過秒数を `versionCode` に使う。同じアプリのデプロイは
ワークフローで直列化するため、手動初回アップロードとワークフロー再実行で番号が衝突せず、
古い実行を後からやり直しても番号が逆戻りしない。

### 事前に用意するもの

署名素材と Play のサービスアカウントは **prod アカウントの SSM Parameter Store** に置き、
CI も手元も `scripts/android-signing.sh` で同じ場所から取る（#405。Firebase 設定と同じ方式。
GitHub Secrets は書き込み専用で手元から読み返せないため、初回の手動アップロードで経路が
分かれるのを避ける）。名前は `terraform/environments/prod/ssm.tf` で管理（値は Terraform 管理外）。

| パラメータ | 中身 |
| --- | --- |
| `/rikako/production/android/upload-keystore` | アップロード鍵の keystore（base64） |
| `/rikako/production/android/upload-keystore-password` | keystore のパスワード |
| `/rikako/production/android/upload-key-alias` | 鍵の alias |
| `/rikako/production/android/upload-key-password` | 鍵のパスワード |
| `/rikako/production/android/play-service-account` | Play Developer API のサービスアカウント JSON |

1. **アップロード鍵**。既存の keystore（RSA 2048 以上、有効期限が 2033-10-22 より後）があれば
   それでよい。無ければ作る:

   ```bash
   keytool -genkeypair -v -keystore upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias key0
   ```

   化学と IT パスポートは**同じアップロード鍵**を使う（ワークフローが 1 組しか持たないため）。
   Play App Signing が必須なので、これは「アップロード鍵」であり本物の署名鍵は Google が持つ。
   紛失しても Google サポート経由でリセットできるが、keystore 本体はパスワードマネージャー等にも保管する。

2. **Play Console にアプリを登録**（`org.rikako.chemistry` / `org.rikako.itpassport` の2本）。
   dev フレーバー（`.dev`）は Play に登録しない（手元インストールか Firebase App Distribution で配る）

3. **サービスアカウント**: Google Cloud で作成 → Play Console の「ユーザーとアクセス権」に招待し、
   対象アプリのリリース権限を付ける。JSON を発行する

4. **SSM に登録**（prod のプロファイルで `aws sso login` 済みで。パスワードは対話入力なので
   コマンド履歴に残らない）。Terraform が先にプレースホルダで作っているので `--overwrite` で上書きになる:

   ```bash
   scripts/android-signing.sh push ~/path/to/upload.jks ~/path/to/play-service-account.json
   ```

5. **最初の1本は手動アップロード**: 新規アプリは Play Console の仕様上、API からの
   アップロードの前に AAB を1度手動で上げる必要がある。

   ```bash
   scripts/firebase-config.sh pull prod android     # google-services.json（無いと prod release は止まる）
   eval "$(scripts/android-signing.sh pull)"        # keystore を一時ディレクトリに復元して環境変数を export
   cd android
   ANDROID_VERSION_CODE=1 ./gradlew :app:bundleChemistryProdRelease   # IT版は :app:bundleItPassportProdRelease
   # → app/build/outputs/bundle/chemistryProdRelease/app-chemistry-prod-release.aab を Play Console に手動アップロード
   ```

鍵が未設定のときは release ビルドが**署名なし**になる（手元でビルドしても Play へは上げられない）。

`deploy-android-prod.yml` は OIDC で `rikako-production-github-actions` を assume し、同じ
スクリプトで SSM から取る。SSM から取った値は Actions が自動マスクしないので、ワークフローで
`::add-mask::` を付けてから環境に入れている。パラメータが未登録（プレースホルダのまま）だと
keystore の復元で失敗して止まる。

Firebase の `google-services.json` も同様に SSM から取る（`scripts/firebase-config.sh pull prod android`）。
詳細は「Firebase」の節を参照。

## CI

`.github/workflows/android.yml` が `android/**` の変更で走る（main への push と PR）。

1. `gradle/actions/wrapper-validation` で `gradle-wrapper.jar` を検証
2. `:app:testChemistryDevDebugUnitTest`（ユニットテスト）
3. `:app:lintChemistryDevDebug`（Android Lint）
4. `:app:assembleChemistryDevDebug` / `:app:assembleItPassportDevDebug`
   （フレーバーごとにリソースが別ディレクトリなので両方ビルドする）
5. `:app:assembleChemistryProdRelease`（R8 の縮小はリリースビルドでしか走らないため）

失敗時は `android/app/build/reports/` をアーティファクトとして残す。

Keystore は実機／エミュレータでしか動かないため、トークン保存まわりだけ計装テストにしてある
（`./gradlew :app:connectedChemistryDevDebugAndroidTest`。CI では動かさない）。

## Firebase（Crashlytics / Analytics）

[#235](https://github.com/takoikatakotako/rikako/issues/235)。iOS と同じ Firebase プロジェクト（dev = 共有 sandbox `sandbox-492513`、prod = `rikako-prd`。2026-09-18 に「prod は `rikako-prd` を使い続ける」で確定）に Android アプリを登録し、`firebase-bom` 経由で `firebase-crashlytics` と `firebase-analytics` を入れている。

| 項目 | ファイル | 役割 |
| --- | --- | --- |
| プラグイン | `build.gradle.kts` / `app/build.gradle.kts` | `google-services` と `firebase-crashlytics`。json が揃っている時だけ適用 |
| 設定 | `CrashReporter.kt` | `FirebaseApp` があれば収集を有効化し `app_slug` をカスタムキーに載せる |
| 結線 | `RikakoApplication` / `MainActivity` | 起動時に `CrashReporter.configure`、debug は `crashIfRequested` |

### google-services.json の扱い（git に載せない）

API キーを含むため `.gitignore` で `**/google-services.json` を除外している（iOS の `GoogleService-Info.plist` と同じ）。
秘密度は低い（APK に同梱されて配布される値）が、CI とローカルが同じ場所から取れるように **SSM Parameter Store** に置く。

| パラメータ | 中身 |
| --- | --- |
| `/rikako/development/firebase/android` | `sandbox-492513` の json（`org.rikako.chemistry.dev` / `org.rikako.itpassport.dev` を登録） |
| `/rikako/production/firebase/android` | `rikako-prd` の json（`org.rikako.chemistry` / `org.rikako.itpassport` を登録） |

いずれも SecureString・手動 put で Terraform 管理外（iOS の plist は同じ階層の `firebase/ios/<app_slug>`）。

```bash
# 配置（AWS_PROFILE 設定 + aws sso login 済みで。dev と prod は別アカウントなので、
# スクリプトが STS でアカウント ID を検証し、違っていれば止まる）
scripts/firebase-config.sh pull dev            # dev の json（+ iOS の dev plist）
# 両環境を 1 回で: 環境ごとのプロファイルを指定する
AWS_PROFILE_DEV=<dev のプロファイル> AWS_PROFILE_PROD=<prod のプロファイル> scripts/firebase-config.sh pull all android

# 初回登録・更新: Firebase コンソールで package name ごとにアプリを登録して json を DL し、
# 下の変種ディレクトリのどれかに置いてから
scripts/firebase-config.sh push prod android
```

```
android/app/src/
├── chemistryDev/google-services.json    # sandbox-492513 の json
├── itPassportDev/google-services.json   # 同上（同じファイル）
├── chemistryProd/google-services.json   # rikako-prd の json
└── itPassportProd/google-services.json  # 同上（同じファイル）
```

`google-services` プラグインは `src/dev/` のような env 単独ディレクトリを探さないので、app×env の 4 変種に置く（1 プロジェクトの json は登録アプリ全部を含むため、dev 用・prod 用の中身はそれぞれ同一でよい）。

**1 つも無い場合はプラグインを適用しない**（`app/build.gradle.kts` の `hasGoogleServicesJson`）。json が無いと `processGoogleServices` がビルドを止めるためで、CI（`android.yml`）や clone 直後の手元でも dev のビルド・テストが通る。この状態ではアプリは Firebase 未初期化で動き、Crashlytics / Analytics は送信しない。

ただし **prod の release（`assemble*ProdRelease` / `bundle*ProdRelease`）は json 無しではビルドを止める**（`androidComponents.onVariants` で `pre*Build` に割り込む）。Crashlytics 無しの AAB を Play に上げないため。手元では `pull prod android` してから作る。CI の `android.yml` は PR から AWS ロールを assume できず json を取れないので、R8 の動作確認のためだけに `-PallowMissingFirebaseConfig=true` で明示的にこのチェックを外している（Play へ上げる `deploy-android-prod.yml` では付けない）。一部の変種にだけ json がある場合（`pull dev` だけした手元など）はプラグイン側が「google-services.json is missing」で止める。

- release は R8 で難読化するので、Crashlytics プラグインが `mapping.txt` を自動アップロードする（`deploy-android-prod.yml` で json を SSM から取ってからビルド）。
- **debug ビルドでも収集する**。dev / prod で Firebase プロジェクトが分かれているため prod のデータは汚れない。
- クラッシュレポートに載せるのは非 PII のキーのみ。ユーザー入力・メールアドレス・Cognito Identity ID は載せない。
- Analytics はライブラリを入れて初期化するところまで。iOS 側のイベント（`app_open` 等）の発火は別途対応する。

### 到達確認（強制クラッシュ）

debug ビルドは起動 Intent に `crashlytics_test_crash=true` を付けると `MainActivity.onCreate` で例外を投げる。

```bash
adb shell am start -n org.rikako.chemistry.dev/org.rikako.quiz.MainActivity --ez crashlytics_test_crash true
```

クラッシュ後にもう一度アプリを起動すると、Firebase コンソール（`sandbox-492513`）の Crashlytics に数分で表示される。

### Play Console のデータセーフティ

Crashlytics を入れた版を上げる前に、Play Console の「データ セーフティ」で**クラッシュログ・診断情報**（アプリの機能向上、共有なし）を申告する。

## iOS と共通の追加機能

- 起動時に `GET /status` を確認し、メンテナンス・必須アップデートを案内する
- 解答時の効果音（iOS と同じ `correct.mp3` / `incorrect.mp3`）・触覚フィードバックを設定で切り替える
- 学習記録の週カレンダー・連続学習日数・53週の学習ヒートマップを表示する
- お知らせ本文の Markdown と未読表示に対応する
- `GET/POST /transfer/token` と `POST /transfer/apply` で匿名データを引き継ぐ。
  QR の表示・スキャン・画像読取・コード貼り付けを用意し、適用前に確認を挟む。
  カメラスキャンは Google Play services に委譲するためアプリの CAMERA 権限は不要。
  ログイン中はアカウント同期と混同しないよう QR 引き継ぎを使えない
