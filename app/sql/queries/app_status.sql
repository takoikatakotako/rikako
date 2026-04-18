-- name: GetAppStatus :one
SELECT is_maintenance, maintenance_message, updated_at FROM app_status WHERE id = TRUE;

-- name: UpdateAppStatus :exec
UPDATE app_status
SET is_maintenance = $1, maintenance_message = $2, updated_at = NOW()
WHERE id = TRUE;
