DROP INDEX IF EXISTS idx_workbooks_category_id;
ALTER TABLE workbooks DROP COLUMN IF EXISTS category_id;
DROP TABLE IF EXISTS categories;
