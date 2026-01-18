-- 問題に紐づく画像
CREATE TABLE question_images (
    id BIGSERIAL PRIMARY KEY,
    question_id BIGINT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    image_path VARCHAR(512) NOT NULL,
    order_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (question_id, order_index)
);

CREATE INDEX idx_question_images_question_id ON question_images(question_id);
