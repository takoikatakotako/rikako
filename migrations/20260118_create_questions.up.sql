CREATE TABLE questions (
    id BIGSERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    text TEXT NOT NULL,
    explanation TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
