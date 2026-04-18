-- name: UpsertUser :one
INSERT INTO users (identity_id) VALUES ($1)
ON CONFLICT (identity_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
RETURNING id;

-- name: GetUserByIdentityID :one
SELECT id FROM users WHERE identity_id = $1;

-- name: CheckAnswerCorrect :one
SELECT EXISTS(
    SELECT 1 FROM questions_single_choice_choices c
    JOIN questions_single_choice qsc ON c.single_choice_id = qsc.id
    WHERE qsc.question_id = $1
      AND c.choice_index = $2
      AND c.is_correct = true
);

-- name: CreateUserAnswer :exec
INSERT INTO user_answers (user_id, question_id, workbook_id, selected_choice, is_correct)
VALUES ($1, $2, $3, $4, $5);

-- name: CountWrongAnswers :one
SELECT COUNT(*) FROM (
    SELECT DISTINCT ON (question_id) is_correct
    FROM user_answers
    WHERE user_id = $1
    ORDER BY question_id, answered_at DESC
) latest WHERE NOT is_correct;

-- name: ListWrongAnswers :many
SELECT q.id, qsc.text, qsc.explanation
FROM (
    SELECT DISTINCT ON (question_id) question_id, is_correct
    FROM user_answers
    WHERE user_id = $1
    ORDER BY question_id, answered_at DESC
) latest
JOIN questions q ON q.id = latest.question_id
JOIN questions_single_choice qsc ON q.id = qsc.question_id
WHERE NOT latest.is_correct
ORDER BY q.id
LIMIT $2 OFFSET $3;

-- name: ListWrongAnswersWithChoices :many
SELECT q.id, qsc.text, qsc.explanation,
    c.text AS choice_text, c.is_correct, c.choice_index
FROM (
    SELECT question_id FROM (
        SELECT DISTINCT ON (question_id) question_id, is_correct
        FROM user_answers
        WHERE user_id = $1
        ORDER BY question_id, answered_at DESC
    ) latest
    WHERE NOT is_correct
    ORDER BY question_id
    LIMIT $2 OFFSET $3
) paged
JOIN questions q ON q.id = paged.question_id
JOIN questions_single_choice qsc ON q.id = qsc.question_id
LEFT JOIN questions_single_choice_choices c ON c.single_choice_id = qsc.id
ORDER BY q.id, c.choice_index;

-- name: ListUsers :many
SELECT id, identity_id, display_name, created_at FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2;

-- name: CountUsers :one
SELECT COUNT(*) FROM users;

-- name: ListUserAnswerLogs :many
SELECT ua.id, ua.question_id, qsc.text AS question_text,
       ua.workbook_id, w.title AS workbook_title,
       ua.selected_choice, ua.is_correct, ua.answered_at
FROM user_answers ua
JOIN questions q ON q.id = ua.question_id
JOIN questions_single_choice qsc ON q.id = qsc.question_id
JOIN workbooks w ON w.id = ua.workbook_id
WHERE ua.user_id = $1
ORDER BY ua.answered_at DESC
LIMIT $2 OFFSET $3;

-- name: CountUserAnswerLogs :one
SELECT COUNT(*) FROM user_answers WHERE user_id = $1;

-- name: GetCorrectChoicesByQuestionIDs :many
SELECT qsc.question_id, c.choice_index
FROM questions_single_choice qsc
JOIN questions_single_choice_choices c ON c.single_choice_id = qsc.id
WHERE qsc.question_id = ANY($1::bigint[])
  AND c.is_correct = true;

-- name: ListWorkbookProgress :many
SELECT DISTINCT ON (question_id) question_id, is_correct
FROM user_answers
WHERE user_id = $1 AND workbook_id = $2
ORDER BY question_id, answered_at DESC;

-- name: GetUserTotalStats :one
SELECT
    COUNT(*)::int AS total_answered,
    COALESCE(SUM(CASE WHEN is_correct THEN 1 ELSE 0 END), 0)::int AS total_correct
FROM user_answers
WHERE user_id = $1;

-- name: GetUserWeeklyStats :one
SELECT
    COUNT(*)::int AS weekly_answered,
    COALESCE(SUM(CASE WHEN is_correct THEN 1 ELSE 0 END), 0)::int AS weekly_correct
FROM user_answers
WHERE user_id = $1 AND answered_at >= $2;

-- name: ListStudyDates :many
SELECT DISTINCT DATE(answered_at)::text AS study_date
FROM user_answers
WHERE user_id = $1
ORDER BY study_date DESC
LIMIT 365;

-- name: ListWeeklyWorkbookIDs :many
SELECT DISTINCT workbook_id
FROM user_answers
WHERE user_id = $1 AND answered_at >= $2;
