CREATE TABLE transfer_tokens (
    id         BIGSERIAL PRIMARY KEY,
    token      VARCHAR(64)  NOT NULL UNIQUE,
    identity_id VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    used_at    TIMESTAMP,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transfer_tokens_token ON transfer_tokens(token);
