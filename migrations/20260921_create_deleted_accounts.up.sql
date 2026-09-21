-- アカウント削除の墓標（Issue #408）。
-- 認証ミドルウェアは JWT の署名と期限しか検証しないため、Cognito のユーザーを消しても
-- 発行済み ID token は期限まで有効に見える。その間に同じ sub で /account/link されると
-- accounts / users が再作成されるので、削除した sub を記録して link を拒否する。
-- 保持するのは sub（Cognito の不透明な UUID）と削除日時だけで、ID token の有効期間（1 時間）に
-- 余裕を見て 7 日で消す（DeleteAccount が毎回 PurgeExpiredDeletedAccounts で掃除する）。
-- 保持の目的と期間はプライバシーポリシーに明記する。
CREATE TABLE deleted_accounts (
    cognito_sub VARCHAR(255) PRIMARY KEY,
    deleted_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
