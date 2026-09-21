-- name: GetAccountByCognitoSub :one
SELECT id, cognito_sub, email, primary_user_id FROM accounts WHERE cognito_sub = $1;

-- name: CreateAccountIfNotExists :one
-- 同一 sub の並行初回リンクに耐えるため ON CONFLICT DO NOTHING。
-- 競合した側は行が返らない（sql.ErrNoRows）ので、呼び出し側が再取得してマージ経路へ進む。
INSERT INTO accounts (cognito_sub, email, primary_user_id)
VALUES ($1, $2, $3)
ON CONFLICT (cognito_sub) DO NOTHING
RETURNING id, cognito_sub, email, primary_user_id;

-- name: GetUserAccountIDForUpdate :one
-- 対象 users 行をロックし、現在の account_id を読む（リンクの直列化・横取り防止）。
SELECT account_id FROM users WHERE id = $1 FOR UPDATE;

-- name: SetUserAccountID :exec
UPDATE users SET account_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2;

-- name: RepointUserAnswersToUser :exec
UPDATE user_answers SET user_id = sqlc.arg(dst)::bigint WHERE user_id = sqlc.arg(src)::bigint;

-- name: MoveUserAppSettingsToUser :exec
INSERT INTO user_app_settings (user_id, app_id, selected_workbook_id, created_at, updated_at)
SELECT sqlc.arg(dst)::bigint, app_id, selected_workbook_id, created_at, updated_at
FROM user_app_settings
WHERE user_id = sqlc.arg(src)::bigint
ON CONFLICT (user_id, app_id) DO NOTHING;

-- name: DeleteUserAppSettingsByUser :exec
DELETE FROM user_app_settings WHERE user_id = $1;

-- name: GetPrimaryUserIDByIdentityID :one
-- 端末が既にアカウントへ紐付いている場合の canonical user を引く。
-- リンク済み端末はログアウト中でも同じアカウントへ読み書きさせるために使う
-- （device user 側に回答が溜まると、再ログイン時の link は冪等 no-op なので回収されない）。
SELECT a.primary_user_id
FROM users u
JOIN accounts a ON a.id = u.account_id
WHERE u.identity_id = $1;

-- name: LockAccountSub :exec
-- 同じ sub に対する link と delete を直列化するトランザクション内アドバイザリロック。
-- 行が無い状態（削除済み・未作成）でもロックできるよう、行ロックではなくこれを使う。
SELECT pg_advisory_xact_lock(hashtext(sqlc.arg(cognito_sub)::text));

-- name: IsAccountDeleted :one
-- 削除済み sub か（墓標）。link はこれが真なら拒否する。
SELECT EXISTS (SELECT 1 FROM deleted_accounts WHERE cognito_sub = $1);

-- name: MarkAccountDeleted :exec
INSERT INTO deleted_accounts (cognito_sub) VALUES ($1)
ON CONFLICT (cognito_sub) DO UPDATE SET deleted_at = CURRENT_TIMESTAMP;

-- name: ListUsersByAccountID :many
-- アカウントに束ねられている users 行（primary を含む全端末）。削除時に一括で消す。
-- identity_id は transfer_tokens（FK 無し・文字列参照）を消すのに使う。
SELECT id, identity_id FROM users WHERE account_id = $1 ORDER BY id;

-- name: DeleteAccountByID :exec
-- accounts.primary_user_id は ON DELETE RESTRICT なので、users を消す前に account を消す
-- （users.account_id は ON DELETE SET NULL）。
DELETE FROM accounts WHERE id = $1;

-- name: DeleteUsersByIDs :exec
-- user_answers / user_app_settings は ON DELETE CASCADE で一緒に消える。
DELETE FROM users WHERE id = ANY($1::bigint[]);
