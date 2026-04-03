-- name: CountWorkbooks :one
SELECT COUNT(*) FROM workbooks;

-- name: ListWorkbooks :many
SELECT w.id, w.title, w.description, w.category_id,
    (SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
FROM workbooks w
ORDER BY w.id
LIMIT $1 OFFSET $2;

-- name: ListAllWorkbooks :many
SELECT w.id, w.title, w.description, w.category_id,
    (SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
FROM workbooks w
ORDER BY w.id;

-- name: GetWorkbookByID :one
SELECT id, title, description, category_id FROM workbooks WHERE id = $1;

-- name: GetWorkbookTitle :one
SELECT title, description, category_id FROM workbooks WHERE id = $1;

-- name: ListQuestionsByWorkbook :many
SELECT q.id, qsc.text, qsc.explanation
FROM questions q
JOIN questions_single_choice qsc ON q.id = qsc.question_id
JOIN workbook_questions wq ON q.id = wq.question_id
WHERE wq.workbook_id = $1
ORDER BY wq.order_index;

-- name: ListQuestionsWithChoicesByWorkbook :many
SELECT q.id, qsc.text, qsc.explanation,
    c.text AS choice_text, c.is_correct, c.choice_index
FROM questions q
JOIN questions_single_choice qsc ON q.id = qsc.question_id
JOIN workbook_questions wq ON q.id = wq.question_id
LEFT JOIN questions_single_choice_choices c ON c.single_choice_id = qsc.id
WHERE wq.workbook_id = $1
ORDER BY wq.order_index, c.choice_index;

-- name: WorkbookExists :one
SELECT EXISTS(SELECT 1 FROM workbooks WHERE id = $1);

-- name: CreateWorkbook :one
INSERT INTO workbooks (title, description, category_id) VALUES ($1, $2, $3) RETURNING id;

-- name: UpdateWorkbook :exec
UPDATE workbooks SET title = $1, description = $2, category_id = $3, updated_at = $4 WHERE id = $5;

-- name: DeleteWorkbookQuestions :exec
DELETE FROM workbook_questions WHERE workbook_id = $1;

-- name: CreateWorkbookQuestion :exec
INSERT INTO workbook_questions (workbook_id, question_id, order_index) VALUES ($1, $2, $3);

-- name: DeleteWorkbook :execresult
DELETE FROM workbooks WHERE id = $1;
