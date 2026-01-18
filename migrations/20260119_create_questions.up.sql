-- 問題（共通）
CREATE TABLE questions (
    id BIGSERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 単一選択問題
CREATE TABLE questions_single_choice (
    id BIGSERIAL PRIMARY KEY,
    question_id BIGINT NOT NULL UNIQUE REFERENCES questions(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    explanation TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 単一選択問題の選択肢
CREATE TABLE questions_single_choice_choices (
    id BIGSERIAL PRIMARY KEY,
    single_choice_id BIGINT NOT NULL REFERENCES questions_single_choice(id) ON DELETE CASCADE,
    choice_index INT NOT NULL,
    text TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (single_choice_id, choice_index)
);

CREATE INDEX idx_questions_single_choice_question_id ON questions_single_choice(question_id);
CREATE INDEX idx_questions_single_choice_choices_single_choice_id ON questions_single_choice_choices(single_choice_id);
