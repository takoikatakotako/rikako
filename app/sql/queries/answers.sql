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

-- name: GetCorrectChoicesByQuestionIDs :many
SELECT qsc.question_id, c.choice_index
FROM questions_single_choice qsc
JOIN questions_single_choice_choices c ON c.single_choice_id = qsc.id
WHERE qsc.question_id = ANY($1::bigint[])
  AND c.is_correct = true;
