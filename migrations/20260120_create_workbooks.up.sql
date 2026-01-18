-- 問題集
CREATE TABLE workbooks (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 問題集と問題の紐付け（多対多）
CREATE TABLE workbook_questions (
    workbook_id BIGINT NOT NULL REFERENCES workbooks(id) ON DELETE CASCADE,
    question_id BIGINT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    order_index INT NOT NULL DEFAULT 0,
    PRIMARY KEY (workbook_id, question_id)
);

CREATE INDEX idx_workbook_questions_workbook_id ON workbook_questions(workbook_id);
CREATE INDEX idx_workbook_questions_question_id ON workbook_questions(question_id);
