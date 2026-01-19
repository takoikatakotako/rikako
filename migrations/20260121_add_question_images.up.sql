-- 画像マスターテーブル
CREATE TABLE images (
    id BIGSERIAL PRIMARY KEY,
    path VARCHAR(512) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 問題と画像の中間テーブル（N:N）
CREATE TABLE question_images (
    question_id BIGINT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    image_id BIGINT NOT NULL REFERENCES images(id) ON DELETE CASCADE,
    order_index INT NOT NULL DEFAULT 0,
    PRIMARY KEY (question_id, image_id),
    UNIQUE (question_id, order_index)
);

CREATE INDEX idx_question_images_question_id ON question_images(question_id);
CREATE INDEX idx_question_images_image_id ON question_images(image_id);
