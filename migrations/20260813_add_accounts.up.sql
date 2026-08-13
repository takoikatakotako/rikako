-- アカウント（Cognito User Pool の sub に対応。1 アカウント = 1 canonical users 行）。
-- 既存の users 行は「デバイス/identity 単位のプロファイル」のまま残し、複数 users を
-- 束ねる accounts を薄く後付けする（設計: docs/email-login-design.md §3, Issue #283）。
CREATE TABLE accounts (
    id              BIGSERIAL PRIMARY KEY,
    cognito_sub     VARCHAR(255) NOT NULL UNIQUE,             -- User Pool の sub
    email           VARCHAR(255),                             -- 表示用（認証・変更の正は Cognito）
    primary_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT, -- canonical users 行
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP           -- 更新時は明示的に CURRENT_TIMESTAMP を設定する
);

-- 「1 account = 1 canonical users 行」（認可境界）を DB 制約で担保する。
CREATE UNIQUE INDEX idx_accounts_primary_user_id ON accounts(primary_user_id);

-- users にアカウント紐付けを追加（NULL = 匿名のまま）。
-- 複数の端末/旧 user 行を 1 account に束ねるため、こちらは非 UNIQUE。
ALTER TABLE users ADD COLUMN account_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL;

CREATE INDEX idx_users_account_id ON users(account_id);
