-- アカウント削除の墓標（Issue #408）。
-- 認証ミドルウェアは JWT の署名と期限しか検証しないため、Cognito のユーザーを消しても
-- 発行済み ID token は期限まで有効に見える。その間に同じ sub で /account/link されると
-- accounts / users が再作成されるので、削除した sub を記録して link を拒否する。
-- 保持するのは sub（Cognito の不透明な UUID）と削除日時だけ。
CREATE TABLE deleted_accounts (
    cognito_sub VARCHAR(255) PRIMARY KEY,
    deleted_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
