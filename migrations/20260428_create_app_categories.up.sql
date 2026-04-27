CREATE TABLE app_categories (
  app_id BIGINT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (app_id, category_id)
);

CREATE INDEX idx_app_categories_category_id ON app_categories(category_id);

INSERT INTO app_categories (app_id, category_id, sort_order)
SELECT a.id, c.id, 0
FROM apps a
JOIN categories c ON c.id = 1
WHERE a.slug = 'high-school-chemistry'
ON CONFLICT DO NOTHING;

INSERT INTO app_categories (app_id, category_id, sort_order)
SELECT a.id, c.id, 0
FROM apps a
JOIN categories c ON c.id = 2
WHERE a.slug = 'it-passport'
ON CONFLICT DO NOTHING;
