-- name: GetImageURLsByQuestionID :many
SELECT i.path
FROM images i
JOIN question_images qi ON i.id = qi.image_id
WHERE qi.question_id = $1
ORDER BY qi.order_index;

-- name: GetImageURLsByQuestionIDs :many
SELECT qi.question_id, i.path
FROM question_images qi
JOIN images i ON i.id = qi.image_id
WHERE qi.question_id = ANY($1::bigint[])
ORDER BY qi.question_id, qi.order_index;

-- name: CreateImage :one
INSERT INTO images (path) VALUES ($1) RETURNING id;

-- name: CreateQuestionImage :exec
INSERT INTO question_images (question_id, image_id, order_index) VALUES ($1, $2, $3);

-- name: DeleteQuestionImages :exec
DELETE FROM question_images WHERE question_id = $1;
