UPDATE apps
SET slug = 'high-school-chemistry', title = '高校化学'
WHERE slug = 'chemistry';

INSERT INTO apps (slug, title)
VALUES ('it-passport', 'ITパスポート')
ON CONFLICT (slug) DO UPDATE SET title = EXCLUDED.title;

