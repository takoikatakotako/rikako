-- users.account_id を先に落としてから accounts を削除する
-- （users.account_id は accounts を参照しているため）。
DROP INDEX IF EXISTS idx_users_account_id;
ALTER TABLE users DROP COLUMN IF EXISTS account_id;

DROP TABLE IF EXISTS accounts;
