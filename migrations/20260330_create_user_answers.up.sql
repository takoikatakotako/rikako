-- ユーザー（匿名ユーザー含む）
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    identity_id VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 回答履歴
CREATE TABLE user_answers (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_id BIGINT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    workbook_id BIGINT NOT NULL REFERENCES workbooks(id) ON DELETE CASCADE,
    selected_choice INT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_answers_user_id ON user_answers(user_id);
CREATE INDEX idx_user_answers_user_question ON user_answers(user_id, question_id);
CREATE INDEX idx_user_answers_user_workbook ON user_answers(user_id, workbook_id);
