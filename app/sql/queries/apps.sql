-- name: GetAppBySlug :one
SELECT id, slug, title FROM apps WHERE slug = $1;

-- name: ListApps :many
SELECT id, slug, title, created_at FROM apps ORDER BY id;

-- name: CountApps :one
SELECT COUNT(*) FROM apps;

-- name: GetAppByID :one
SELECT id, slug, title, created_at FROM apps WHERE id = $1;

-- name: ListAppCategoriesBySlug :many
SELECT c.id, c.title, c.description, ac.sort_order
FROM apps a
JOIN app_categories ac ON ac.app_id = a.id
JOIN categories c ON c.id = ac.category_id
WHERE a.slug = $1
ORDER BY ac.sort_order, c.id;

-- name: ListAppCategoryIDsBySlug :many
SELECT ac.category_id
FROM apps a
JOIN app_categories ac ON ac.app_id = a.id
WHERE a.slug = $1
ORDER BY ac.sort_order, ac.category_id;

-- name: CreateApp :one
INSERT INTO apps (slug, title) VALUES ($1, $2) RETURNING id;

-- name: UpdateApp :exec
UPDATE apps SET slug = $1, title = $2 WHERE id = $3;

-- name: DeleteApp :execresult
DELETE FROM apps WHERE id = $1;

-- name: UpdateUserDisplayName :exec
UPDATE users SET display_name = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2;

-- name: GetUserProfile :one
SELECT id, identity_id, display_name, created_at FROM users WHERE id = $1;

-- name: UpsertUserAppSetting :exec
INSERT INTO user_app_settings (user_id, app_id, selected_workbook_id)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, app_id) DO UPDATE SET
    selected_workbook_id = $3,
    updated_at = CURRENT_TIMESTAMP;

-- name: GetUserAppSetting :one
SELECT uas.id, uas.selected_workbook_id, uas.created_at, uas.updated_at
FROM user_app_settings uas
WHERE uas.user_id = $1 AND uas.app_id = $2;

-- name: ListUserAppSettings :many
SELECT uas.id, a.slug AS app_slug, a.title AS app_title, uas.selected_workbook_id, uas.updated_at
FROM user_app_settings uas
JOIN apps a ON a.id = uas.app_id
WHERE uas.user_id = $1
ORDER BY a.id;
