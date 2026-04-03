-- name: CountCategories :one
SELECT COUNT(*) FROM categories;

-- name: ListCategories :many
SELECT c.id, c.title, c.description,
    (SELECT COUNT(*) FROM workbooks w WHERE w.category_id = c.id) as workbook_count
FROM categories c
ORDER BY c.id
LIMIT $1 OFFSET $2;

-- name: ListAllCategories :many
SELECT c.id, c.title, c.description,
    (SELECT COUNT(*) FROM workbooks w WHERE w.category_id = c.id) as workbook_count
FROM categories c
ORDER BY c.id;

-- name: GetCategoryByID :one
SELECT id, title, description FROM categories WHERE id = $1;

-- name: GetCategoryTitle :one
SELECT title, description FROM categories WHERE id = $1;

-- name: ListWorkbooksByCategory :many
SELECT w.id, w.title, w.description,
    (SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
FROM workbooks w
WHERE w.category_id = $1
ORDER BY w.id;

-- name: CreateCategory :one
INSERT INTO categories (title, description) VALUES ($1, $2) RETURNING id;

-- name: CategoryExists :one
SELECT EXISTS(SELECT 1 FROM categories WHERE id = $1);

-- name: UpdateCategory :exec
UPDATE categories SET title = $1, description = $2, updated_at = $3 WHERE id = $4;

-- name: DeleteCategory :execresult
DELETE FROM categories WHERE id = $1;
