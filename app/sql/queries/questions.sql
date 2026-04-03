-- name: CountQuestions :one
SELECT COUNT(*) FROM questions;

-- name: ListQuestions :many
SELECT q.id, qsc.text, qsc.explanation
FROM questions q
JOIN questions_single_choice qsc ON q.id = qsc.question_id
ORDER BY q.id
LIMIT $1 OFFSET $2;

-- name: GetQuestionByID :one
SELECT q.id, qsc.text, qsc.explanation
FROM questions q
JOIN questions_single_choice qsc ON q.id = qsc.question_id
WHERE q.id = $1;

-- name: GetChoicesByQuestionID :many
SELECT text, is_correct, choice_index
FROM questions_single_choice_choices
WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
ORDER BY choice_index;

-- name: ListQuestionsWithChoices :many
SELECT q.id, qsc.text, qsc.explanation,
    c.text AS choice_text, c.is_correct, c.choice_index
FROM questions q
JOIN questions_single_choice qsc ON q.id = qsc.question_id
LEFT JOIN questions_single_choice_choices c ON c.single_choice_id = qsc.id
WHERE q.id IN (SELECT id FROM questions ORDER BY id LIMIT $1 OFFSET $2)
ORDER BY q.id, c.choice_index;

-- name: CreateQuestion :one
INSERT INTO questions (type) VALUES ($1) RETURNING id;

-- name: CreateSingleChoice :one
INSERT INTO questions_single_choice (question_id, text, explanation)
VALUES ($1, $2, $3) RETURNING id;

-- name: CreateChoice :exec
INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct)
VALUES ($1, $2, $3, $4);

-- name: UpdateSingleChoice :exec
UPDATE questions_single_choice
SET text = $1, explanation = $2, updated_at = $3
WHERE question_id = $4;

-- name: DeleteChoicesByQuestionID :exec
DELETE FROM questions_single_choice_choices
WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1);

-- name: GetSingleChoiceID :one
SELECT id FROM questions_single_choice WHERE question_id = $1;

-- name: UpdateQuestionTimestamp :exec
UPDATE questions SET updated_at = $1 WHERE id = $2;

-- name: DeleteQuestion :execresult
DELETE FROM questions WHERE id = $1;

-- name: QuestionExists :one
SELECT EXISTS(SELECT 1 FROM questions WHERE id = $1);
