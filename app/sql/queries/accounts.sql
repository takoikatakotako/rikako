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
