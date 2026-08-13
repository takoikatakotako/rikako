-- name: GetAccountByCognitoSub :one
SELECT id, cognito_sub, email, primary_user_id FROM accounts WHERE cognito_sub = $1;

-- name: CreateAccount :one
INSERT INTO accounts (cognito_sub, email, primary_user_id)
VALUES ($1, $2, $3)
RETURNING id, cognito_sub, email, primary_user_id;

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
