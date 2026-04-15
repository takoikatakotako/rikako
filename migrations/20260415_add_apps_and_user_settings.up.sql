-- アプリ定義
CREATE TABLE apps (
    id BIGSERIAL PRIMARY KEY,
    slug VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 初期データ
INSERT INTO apps (slug, title) VALUES ('chemistry', '高校化学');

-- ユーザーに表示名を追加
ALTER TABLE users ADD COLUMN display_name VARCHAR(255);

-- ユーザー × アプリごとの設定
CREATE TABLE user_app_settings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    app_id BIGINT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    selected_workbook_id BIGINT REFERENCES workbooks(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, app_id)
);

CREATE INDEX idx_user_app_settings_user_id ON user_app_settings(user_id);
