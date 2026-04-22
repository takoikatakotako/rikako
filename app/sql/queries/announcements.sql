-- name: ListAnnouncements :many
SELECT id, title, body, category, published_at, created_at, updated_at
FROM announcements
ORDER BY published_at DESC, id DESC
LIMIT $1 OFFSET $2;

-- name: ListLatestAnnouncements :many
SELECT id, title, body, category, published_at, created_at, updated_at
FROM announcements
ORDER BY published_at DESC, id DESC
LIMIT $1;

-- name: CountAnnouncements :one
SELECT COUNT(*) FROM announcements;

-- name: GetAnnouncement :one
SELECT id, title, body, category, published_at, created_at, updated_at
FROM announcements
WHERE id = $1;

-- name: CreateAnnouncement :one
INSERT INTO announcements (title, body, category, published_at)
VALUES ($1, $2, $3, $4)
RETURNING id;

-- name: UpdateAnnouncement :exec
UPDATE announcements
SET title = $1, body = $2, category = $3, published_at = $4, updated_at = NOW()
WHERE id = $5;

-- name: DeleteAnnouncement :execresult
DELETE FROM announcements WHERE id = $1;

-- name: AnnouncementExists :one
SELECT EXISTS(SELECT 1 FROM announcements WHERE id = $1);
