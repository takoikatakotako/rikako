-- app_categories の再シード（冪等）。
--
-- 背景:
--   20260428_create_app_categories のシードは categories テーブルにカテゴリ行が
--   投入される前（datasync 前）に実行されると、JOIN categories が 0 行になり
--   app_categories に何も挿入されない。ワンショットのため以後 datasync で
--   カテゴリが投入されても空のまま固定される。
--   prod で実際にこの状態が発生し、GET /apps/{slug} の categories が空 →
--   iOS オンボーディングで問題集が 0 件になり審査で先に進めなかった（リジェクト）。
--
-- 対応:
--   カテゴリ行が揃っている状態で app_categories を冪等に再シードする。
--   ON CONFLICT DO NOTHING なので既に紐付け済みの環境（dev 等）には影響しない。

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
