-- アカウント削除の墓標（Issue #408）。
-- 認証ミドルウェアは JWT の署名と期限しか検証しないため、Cognito のユーザーを消しても
-- 発行済み ID token は期限まで有効に見える。その間に同じ sub で /account/link されると
-- accounts / users が再作成されるので、削除した sub を記録して link を拒否する。
--
-- cognito_deleted_at は Cognito User Pool 側の削除が確認できた時刻。NULL の間（DB は消えたが
-- Cognito の削除に失敗した状態）はユーザーが再ログインして新しい token を取れるため、
-- 墓標を消してはいけない。Cognito 削除確認から 7 日（ID token 有効期間 1 時間に余裕）で
-- 期限切れとして掃除する。保持の目的と期間はプライバシーポリシーに明記する。
CREATE TABLE deleted_accounts (
    cognito_sub        VARCHAR(255) PRIMARY KEY,
    deleted_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cognito_deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_deleted_accounts_cognito_deleted_at ON deleted_accounts(cognito_deleted_at);
