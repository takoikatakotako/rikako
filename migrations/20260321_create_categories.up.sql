-- カテゴリ
CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 問題集にカテゴリID追加
ALTER TABLE workbooks ADD COLUMN category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL;
CREATE INDEX idx_workbooks_category_id ON workbooks(category_id);
