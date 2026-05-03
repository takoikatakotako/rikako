-- name: GetActiveTransferToken :one
SELECT token, expires_at FROM transfer_tokens
WHERE identity_id = $1
  AND used_at IS NULL
  AND expires_at > CURRENT_TIMESTAMP
ORDER BY created_at DESC
LIMIT 1;

-- name: DeleteTransferTokensByIdentityID :exec
DELETE FROM transfer_tokens WHERE identity_id = $1;

-- name: CreateTransferToken :one
INSERT INTO transfer_tokens (token, identity_id, expires_at)
VALUES ($1, $2, $3)
RETURNING token, expires_at;

-- name: GetTransferTokenIdentityID :one
SELECT identity_id FROM transfer_tokens
WHERE token = $1
  AND used_at IS NULL
  AND expires_at > CURRENT_TIMESTAMP;

-- name: ConsumeTransferToken :one
UPDATE transfer_tokens
SET used_at = CURRENT_TIMESTAMP
WHERE token = $1
  AND used_at IS NULL
  AND expires_at > CURRENT_TIMESTAMP
RETURNING identity_id;
