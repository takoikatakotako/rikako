# メールアドレスログイン設計（Issue #283）

複数端末・Web で同じ学習記録を閲覧・継続できるよう、Cognito **User Pool** による本ログインを導入する。本書は実装前の設計合意を目的とし、データモデル・API・段階的な実装計画・未決事項をまとめる。

- 対象 Issue: [#283](https://github.com/takoikatakotako/rikako/issues/283)
- ステータス: **Phase 1 着手（2026-08-13）** — `accounts` migration は PR #299。跨ぎ SSO 無し等の方針は確定。5.2 / 5.4 / 5.5 / 5.6 は未決。
- 関連: [アーキテクチャ](architecture.md) / [iOSアプリ](ios.md) / 既存の機種変引き継ぎ（Transfer / QR）

---

## 1. 現状（As-Is）

### 認証・ユーザー解決
- 普段は **匿名 Cognito Identity Pool** のみ。iOS は Amplify を使わず raw URLSession で `cognito-identity` を直叩きし、Identity ID を Keychain に保存（`CognitoDeviceIdentityProvider`）。
- API リクエストは `X-Device-ID`（= 匿名 Identity ID）で本人を示し、サーバーは `users.identity_id`（UNIQUE）で 1 対 1 解決する。
- **`users` テーブルは `identity_id` のみ**を持ち、「アカウント」という概念も、1 アカウントに複数 identity を束ねる仕組みもない。

### User Pool（プロビジョニング済み・未結線）
- `terraform/modules/cognito`：email をユーザー名／自動検証、セルフ登録可、パスワードポリシーは記号必須の 8 文字以上。
- App Client：`generate_secret = false`（**client secret なし → SECRET_HASH 不要**）、`explicit_auth_flows = [ALLOW_USER_SRP_AUTH, ALLOW_REFRESH_TOKEN_AUTH]`。
- サーバーの `auth.NewAuthMiddleware` は User Pool JWT を検証し `sub` を context に入れるが、**学習系エンドポイントは全て `publicOperations`** で、`sub` はどのハンドラでも使われていない。

### iOS（dead stub）
- `LoginView` / `SignUpView` は画面到達不可。ボタンは `appState.setLoggedIn(true)` を呼ぶだけで Cognito 呼び出しもメール確認もない。
- `AppState` に `userId` / `displayName` の箱はあるが未使用。

### Transfer（QR 引き継ぎ）
- トークンを介して **新端末が旧端末の `identity_id` を「乗っ取る」** モデル（行のマージではなく identity の再利用）。`ApplyTransferToken` は発行元 identity_id を返し、新端末はそれを自分の `X-Device-ID` として採用する。

---

## 2. 目標（To-Be）

1. メールアドレスでサインアップ／ログイン／サインアウト／パスワード再設定ができる。
2. 匿名で貯めた学習データをログイン時にアカウントへ**マージ**する。
3. 別端末・Web からログインすると**同じアカウントの同じ学習記録**が見られる。
4. **未ログイン（匿名）利用は従来どおり**維持する。
5. スタブ（`setLoggedIn(true)` だけの実装）を解消する。

### ドメイン・トポロジー（ポータル + アプリ別）

「Google アカウント → Gmail / Drive」と同型の **ポータル + 各アプリ** 構成を採る。

- `rikako.org`：アカウントのポータル。ログインして**プロフィール**と**利用中サービス（IT / Chemist）**を確認できる。
- `it.rikako.org` / `chemist.rikako.org`：各科目アプリ。ログインして**そのアプリの学習履歴**を見る。
- iOS（化学版など）：同じアカウントでログインし、同じ学習記録を継続。

認証は **User Pool が環境ごとに 1 つ**（アプリ別ではない）ため、`sub` = 全アプリ共通のアカウント。「どのサービスを使っているか」は、そのアカウントに紐づく `apps`（`user_app_settings` / `user_answers → workbook → app`）を引けば出せる（データモデルは §3 で既に対応）。

> **跨ぎ SSO はやらない（決定）**：`rikako.org` でログインしても `it` / `chemist` に自動ログインはしない。**サイト（サブドメイン）ごとに個別ログイン**する。理由：複数サイトを行き来する頻度が低く、跨ぎ SSO（Hosted UI + `.rikako.org` Cookie 等）のコストに見合わない。この判断により Web も **手書き `USER_PASSWORD_AUTH` + サブドメイン単位のトークン保管**で済む（§4・§5.1）。将来 SSO が必要になったら Cognito Hosted UI + `.rikako.org` Cookie へ移行できる（後方互換）。

---

## 3. データモデル設計

### 3.1 方針：`users` に「アカウント」を後付けする（accounts 分離はしない）

現行は全クエリが `user_id`（= `users.id`）で学習データを引く。ここに新テーブルを増やして全クエリを書き換えるのは影響が大きい。**既存の `users` 行を「デバイス/identity 単位のプロファイル」のまま残し、複数 `users` を束ねる `accounts` を薄く導入**、学習データは引き続き `user_id` で引くが、**ログイン後は全端末が同じ `users` 行に解決される**設計にする。

考え方は Transfer と同じ「1 つの canonical な users 行に寄せる」の発展形：

- `accounts`：Cognito User Pool の `sub`（= 本アカウント）に対応。1 アカウント = 1 canonical `users.id`。
- ログイン端末は、自分の匿名 `users` 行を canonical 行へ**マージ**（`user_answers` などを付け替え）し、以降は canonical 行を使う。

```sql
-- migrations/20260813_add_accounts.up.sql（PR #299）
CREATE TABLE accounts (
    id            BIGSERIAL PRIMARY KEY,
    cognito_sub   VARCHAR(255) NOT NULL UNIQUE,   -- User Pool の sub
    email         VARCHAR(255),                    -- 表示用（正は Cognito 側）
    primary_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT, -- canonical users 行
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 「1 account = 1 canonical users 行」（認可境界）を UNIQUE 制約で担保
CREATE UNIQUE INDEX idx_accounts_primary_user_id ON accounts(primary_user_id);

-- users にアカウント紐付けを追加（NULL = 匿名のまま。複数 users を 1 account に束ねるので非 UNIQUE）
ALTER TABLE users ADD COLUMN account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL;
```

> `email` は表示用の非正規コピー。認証・変更の正は Cognito。`primary_user_id` は UNIQUE（1 account = 1 canonical user、認可境界）。`updated_at` は自動更新されないため、更新クエリで明示的に `updated_at = CURRENT_TIMESTAMP` を設定する。

### 3.2 解決ロジック（サーバー）

現状 `X-Device-ID → users.identity_id → users.id` を、次の優先順で共通ヘルパ `resolveUserID(ctx)` に集約する：

1. `Authorization: Bearer <IdToken>` があり検証 OK → `sub` から `accounts` を引き、`primary_user_id` を使う。
2. なければ従来どおり `X-Device-ID` から `users` を upsert して使う。

これにより **ログイン中は端末に関係なく同じ `user_id`** に解決され、学習系クエリ（`answers.sql` 群）は無改修で複数端末一貫になる。

### 3.3 マージ（匿名 → アカウント）

ログイン／サインアップ確定時に呼ぶ `POST /account/link` 相当で以下をトランザクション実行：

1. `sub` の `accounts` が無ければ作成。`primary_user_id` は「その時点で最も学習量が多い users 行」または「新規 canonical 行」を採用（下記 5.2 で要決定）。
2. 端末の匿名 `users`（`X-Device-ID`）の `user_answers` / `user_app_settings` を `primary_user_id` へ付け替え。
3. 重複回答の扱い（同 question の履歴）を決める（追記でよい／集計は `DISTINCT ON` 最新なので実害小）。
4. 付け替え元の匿名 `users` 行は残す（別端末が再ログインするまで匿名継続に使えるため）か、`account_id` を張るだけにする。

**冪等**であること（同じ端末が再ログインしても壊れない）を必須要件とする。

---

## 4. Cognito 認証フロー（Amplify 非依存）

iOS/Web とも Amplify を使わず、Cognito の HTTPS API を直叩きする既存流儀に合わせる。**client secret 無しなので SECRET_HASH 不要**。

必要な操作（`cognito-idp` の各 Target）:

| 機能 | API |
|---|---|
| サインアップ | `SignUp` → `ConfirmSignUp`（メール確認コード） |
| ログイン | `InitiateAuth`（下記フロー要決定）→ IdToken/AccessToken/RefreshToken |
| トークン更新 | `InitiateAuth`（`REFRESH_TOKEN_AUTH`） |
| パスワード再設定 | `ForgotPassword` → `ConfirmForgotPassword` |
| サインアウト | ローカルのトークン破棄（+任意で `GlobalSignOut`） |

> **認証フローの選択（要決定・5.1）**：現状の App Client は `ALLOW_USER_SRP_AUTH` のみ。SRP を手書きするのは重いので、`ALLOW_USER_PASSWORD_AUTH` を追加して `USER_PASSWORD_AUTH`（メール＋パスワードを TLS でそのまま送る）を使うのが実装コスト最小。セキュリティ的にも TLS 前提で一般的だが、方針として合意が必要。Terraform の `explicit_auth_flows` に 1 行追加するだけ。

トークン保管：iOS は Keychain（既存 `KeychainIdentityStore` に倣う）、Web は Cookie/`localStorage`（要決定 5.3）。

---

## 5. 未決事項（要決定）

**決定済み**

- **跨ぎ SSO はやらない**：サブドメインごとに個別ログイン（§2 参照）。→ 認証フローは手書き、Web はサブドメイン単位でトークン保管。

**要決定**

| # | 論点 | 選択肢 / 推奨 |
|---|---|---|
| 5.1 | 認証フロー | **`USER_PASSWORD_AUTH` を有効化（推奨・実装最小、跨ぎSSO不要なので確定寄り）** / SRP を手書き |
| 5.2 | マージ時の canonical 行 | 学習量の多い方を採用 / 常に新規行 / 初回ログイン端末を採用 |
| 5.3 | Web のトークン保管 | 跨ぎ不要なので **サブドメイン単位の localStorage で可（実装簡単、XSS 注意）** / httpOnly Cookie |
| 5.4 | Transfer(QR) との役割整理 | ログイン導入後も QR は「アカウント無しの一時引き継ぎ」として残す / 段階的に廃止 |
| 5.5 | メール確認前の扱い | 確認前はログイン不可（Cognito 既定）でよいか |
| 5.6 | 複数匿名 identity の統合 | 別端末で先に匿名利用 → 後からログインした場合の重複データ扱い（5.2 と連動） |

---

## 6. 段階的な実装計画（PR 分割）

一度に 3 プラットフォームは扱わない。基盤 → iOS → Web の順。

### Phase 0 — 設計合意（本書）
- 本ドキュメントのレビューと 5 章の意思決定。以降の PR はここで確定した方針に従う。

### Phase 1 — バックエンド基盤（1〜2 PR）
- `accounts` テーブル + `users.account_id` の migration。
- sqlc クエリ追加（accounts upsert / users のマージ付け替え / sub→primary_user_id 解決）。
- `resolveUserID` ヘルパで「JWT 優先・無ければ X-Device-ID」を共通化し、学習系ハンドラを差し替え。
- `POST /account/link`（匿名→アカウントのマージ、冪等）を openapi.yaml に追加し実装。
- 認証必須化：`/account/*` は `publicOperations` から外す。学習系は「JWT があれば使う／無ければ従来」を許容（後方互換）。
- テスト：マージの冪等性、複数端末で同一 user_id 解決。
- migration は dev デプロイ後に `Run Database Migration (Dev)` を手動 dispatch（運用ルール）。

### Phase 2 — iOS 結線（2〜3 PR）
- Cognito User Pool クライアント（SignUp/Confirm/InitiateAuth/Refresh/Forgot）を URLSession で実装（`Infrastructure/Auth`）。
- `LoginView`/`SignUpView` を実結線、確認コード画面・パスワード再設定画面を追加、設定/マイページから導線。
- ログイン成功で IdToken を保持し、API 呼び出しに `Authorization` を付与。`POST /account/link` でマージ。
- `AppState` の `isLoggedIn`/`userId`/`displayName` を実データで駆動。未ログイン時は従来の匿名フロー維持。

### Phase 3 — Web / ポータル（2〜3 PR）
- Web は静的焼き込み配信（[web-publish-coupling] の制約に注意）。ログインは動的呼び出しになるためアーキ整理が必要。
- **各アプリサイト（it / chemist）**：ログイン UI + サブドメイン単位のトークン保管（5.3）+ そのアプリの学習記録の閲覧（同一アカウント・同一データ）。
- **rikako.org ポータル**：ログインしてプロフィール + 利用中サービス（`apps`）の一覧を表示。各アプリサイトへの導線を出す。
- 跨ぎ SSO は実装しない（§2 決定）。各サブドメインで個別ログインする前提で UI 文言を整える。

### 横断
- Terraform：`explicit_auth_flows` に `ALLOW_USER_PASSWORD_AUTH` 追加（5.1 合意後、dev→prod）。
- ドキュメント：本書を「実装済み」に更新し、[アーキテクチャ](architecture.md) の認証節を改訂。

---

## 7. リスク / 留意

- **マージはトランザクション内で複数クエリを流す**。旧 lib/pq は Neon pooler 非互換（複数クエリで 500）だったが、**pgx(stdlib) + simple protocol へ移行済み（#292）で dev/prod とも pooled endpoint で安定動作（#293 / #294）**。この懸念は解消済み。
- 既存の全学習クエリが `user_id` 依存なので、**解決ロジックの一点集約が肝**。ここを誤ると匿名データの取りこぼし/二重計上が起きる。
- Transfer(QR) とアカウントの二重引き継ぎ経路が並存するため、ユーザー体験の整理（5.4）を UI 文言含めて決める。
