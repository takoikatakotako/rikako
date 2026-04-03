-- name: DeleteAllWorkbookQuestions :exec
DELETE FROM workbook_questions;

-- name: DeleteAllWorkbooks :exec
DELETE FROM workbooks;

-- name: DeleteAllCategories :exec
DELETE FROM categories;

-- name: DeleteAllQuestionImages :exec
DELETE FROM question_images;

-- name: DeleteAllChoices :exec
DELETE FROM questions_single_choice_choices;

-- name: DeleteAllSingleChoices :exec
DELETE FROM questions_single_choice;

-- name: DeleteAllQuestions :exec
DELETE FROM questions;

-- name: DeleteAllImages :exec
DELETE FROM images;

-- name: ImportImage :exec
INSERT INTO images (id, path) VALUES ($1, $2);

-- name: ImportQuestion :exec
INSERT INTO questions (id, type) VALUES ($1, $2);

-- name: ImportSingleChoice :one
INSERT INTO questions_single_choice (question_id, text, explanation)
VALUES ($1, $2, $3) RETURNING id;

-- name: ImportChoice :exec
INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct)
VALUES ($1, $2, $3, $4);

-- name: ImportQuestionImage :exec
INSERT INTO question_images (question_id, image_id, order_index) VALUES ($1, $2, $3);

-- name: ImportWorkbook :exec
INSERT INTO workbooks (id, title, description) VALUES ($1, $2, $3);

-- name: ImportWorkbookQuestion :exec
INSERT INTO workbook_questions (workbook_id, question_id, order_index) VALUES ($1, $2, $3);

-- name: ImportCategory :exec
INSERT INTO categories (id, title, description) VALUES ($1, $2, $3);

-- name: SetWorkbookCategory :exec
UPDATE workbooks SET category_id = $1 WHERE id = $2;
