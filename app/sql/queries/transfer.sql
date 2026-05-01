-- name: CreateTransferToken :exec
INSERT INTO transfer_tokens (token, identity_id, expires_at)
VALUES ($1, $2, $3);

-- name: ConsumeTransferToken :one
UPDATE transfer_tokens
SET used_at = CURRENT_TIMESTAMP
WHERE token = $1
  AND used_at IS NULL
  AND expires_at > CURRENT_TIMESTAMP
RETURNING identity_id;
