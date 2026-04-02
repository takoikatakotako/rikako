package handler

import (
	"context"
	"database/sql"

	"github.com/takoikatakotako/rikako/internal/api"
)

func (h *Handler) SubmitAnswers(ctx context.Context, request api.SubmitAnswersRequestObject) (api.SubmitAnswersResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.SubmitAnswers400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	if request.Body == nil || len(request.Body.Answers) == 0 {
		return api.SubmitAnswers400JSONResponse{Code: "INVALID_PARAMETER", Message: "answers are required"}, nil
	}

	// Upsert user
	var userID int64
	err := h.db.QueryRowContext(ctx, `
		INSERT INTO users (identity_id) VALUES ($1)
		ON CONFLICT (identity_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
		RETURNING id
	`, deviceID).Scan(&userID)
	if err != nil {
		h.logger.Error("failed to upsert user", "error", err, "device_id", deviceID)
		return nil, err
	}

	// Verify workbook exists
	var workbookExists bool
	err = h.db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM workbooks WHERE id = $1)`, request.Body.WorkbookId).Scan(&workbookExists)
	if err != nil {
		h.logger.Error("failed to check workbook", "error", err)
		return nil, err
	}
	if !workbookExists {
		return api.SubmitAnswers400JSONResponse{Code: "INVALID_PARAMETER", Message: "workbook not found"}, nil
	}

	correctCount := 0
	for _, answer := range request.Body.Answers {
		// Check if the selected choice is correct
		var isCorrect bool
		err := h.db.QueryRowContext(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM questions_single_choice_choices c
				JOIN questions_single_choice qsc ON c.single_choice_id = qsc.id
				WHERE qsc.question_id = $1
				  AND c.choice_index = $2
				  AND c.is_correct = true
			)
		`, answer.QuestionId, answer.SelectedChoice).Scan(&isCorrect)
		if err != nil {
			h.logger.Error("failed to check answer", "error", err, "question_id", answer.QuestionId)
			return nil, err
		}

		if isCorrect {
			correctCount++
		}

		// Insert answer record
		_, err = h.db.ExecContext(ctx, `
			INSERT INTO user_answers (user_id, question_id, workbook_id, selected_choice, is_correct)
			VALUES ($1, $2, $3, $4, $5)
		`, userID, answer.QuestionId, request.Body.WorkbookId, answer.SelectedChoice, isCorrect)
		if err != nil {
			h.logger.Error("failed to insert answer", "error", err, "question_id", answer.QuestionId)
			return nil, err
		}
	}

	return api.SubmitAnswers200JSONResponse{
		CorrectCount: correctCount,
		TotalCount:   len(request.Body.Answers),
	}, nil
}

func (h *Handler) GetWrongAnswers(ctx context.Context, request api.GetWrongAnswersRequestObject) (api.GetWrongAnswersResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.GetWrongAnswers400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetWrongAnswers400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	// Get user ID
	var userID int64
	err = h.db.QueryRowContext(ctx, `SELECT id FROM users WHERE identity_id = $1`, deviceID).Scan(&userID)
	if err == sql.ErrNoRows {
		// No user found — return empty list
		return api.GetWrongAnswers200JSONResponse{Questions: []api.Question{}, Total: 0}, nil
	}
	if err != nil {
		h.logger.Error("failed to get user", "error", err, "device_id", deviceID)
		return nil, err
	}

	// Get questions where the latest answer is wrong
	// Uses DISTINCT ON to get only the most recent answer per question
	var total int
	err = h.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM (
			SELECT DISTINCT ON (question_id) is_correct
			FROM user_answers
			WHERE user_id = $1
			ORDER BY question_id, answered_at DESC
		) latest WHERE NOT is_correct
	`, userID).Scan(&total)
	if err != nil {
		h.logger.Error("failed to count wrong answers", "error", err)
		return nil, err
	}

	rows, err := h.db.QueryContext(ctx, `
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
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		h.logger.Error("failed to query wrong answers", "error", err)
		return nil, err
	}
	defer rows.Close()

	questions := []api.Question{}
	for rows.Next() {
		var qid int64
		var text string
		var explanation sql.NullString

		if err := rows.Scan(&qid, &text, &explanation); err != nil {
			h.logger.Error("failed to scan question", "error", err)
			return nil, err
		}

		// Get choices
		choiceRows, err := h.db.QueryContext(ctx, `
			SELECT text, is_correct, choice_index
			FROM questions_single_choice_choices
			WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
			ORDER BY choice_index
		`, qid)
		if err != nil {
			h.logger.Error("failed to query choices", "error", err, "question_id", qid)
			return nil, err
		}

		var choices []string
		var correct int
		for choiceRows.Next() {
			var choiceText string
			var isCorrect bool
			var choiceIndex int
			if err := choiceRows.Scan(&choiceText, &isCorrect, &choiceIndex); err != nil {
				choiceRows.Close()
				return nil, err
			}
			choices = append(choices, choiceText)
			if isCorrect {
				correct = choiceIndex
			}
		}
		choiceRows.Close()

		q := api.Question{
			Id:      qid,
			Type:    api.SingleChoice,
			Text:    text,
			Choices: choices,
			Correct: &correct,
		}
		if explanation.Valid {
			q.Explanation = &explanation.String
		}

		imageURLs, err := h.getImageURLs(ctx, qid)
		if err != nil {
			h.logger.Error("failed to get image URLs", "error", err, "question_id", qid)
			return nil, err
		}
		if len(imageURLs) > 0 {
			q.Images = &imageURLs
		}

		questions = append(questions, q)
	}

	return api.GetWrongAnswers200JSONResponse{
		Questions: questions,
		Total:     total,
	}, nil
}

