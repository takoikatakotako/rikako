package handler

import (
	"context"
	"database/sql"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/db"
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
	userID, err := h.queries.UpsertUser(ctx, deviceID)
	if err != nil {
		h.logger.Error("failed to upsert user", "error", err, "device_id", deviceID)
		return nil, err
	}

	// Verify workbook exists
	exists, err := h.queries.WorkbookExists(ctx, request.Body.WorkbookId)
	if err != nil {
		h.logger.Error("failed to check workbook", "error", err)
		return nil, err
	}
	if !exists {
		return api.SubmitAnswers400JSONResponse{Code: "INVALID_PARAMETER", Message: "workbook not found"}, nil
	}

	correctCount := 0
	for _, answer := range request.Body.Answers {
		isCorrect, err := h.queries.CheckAnswerCorrect(ctx, db.CheckAnswerCorrectParams{
			QuestionID:  answer.QuestionId,
			ChoiceIndex: int32(answer.SelectedChoice),
		})
		if err != nil {
			h.logger.Error("failed to check answer", "error", err, "question_id", answer.QuestionId)
			return nil, err
		}

		if isCorrect {
			correctCount++
		}

		err = h.queries.CreateUserAnswer(ctx, db.CreateUserAnswerParams{
			UserID:         userID,
			QuestionID:     answer.QuestionId,
			WorkbookID:     request.Body.WorkbookId,
			SelectedChoice: int32(answer.SelectedChoice),
			IsCorrect:      isCorrect,
		})
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

	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if err == sql.ErrNoRows {
		return api.GetWrongAnswers200JSONResponse{Questions: []api.Question{}, Total: 0}, nil
	}
	if err != nil {
		h.logger.Error("failed to get user", "error", err, "device_id", deviceID)
		return nil, err
	}

	total, err := h.queries.CountWrongAnswers(ctx, userID)
	if err != nil {
		h.logger.Error("failed to count wrong answers", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListWrongAnswers(ctx, db.ListWrongAnswersParams{
		UserID: userID,
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to query wrong answers", "error", err)
		return nil, err
	}

	questions := []api.Question{}
	for _, row := range rows {
		q, err := h.buildQuestion(ctx, row.ID, row.Text, row.Explanation)
		if err != nil {
			h.logger.Error("failed to build question", "error", err, "question_id", row.ID)
			return nil, err
		}
		questions = append(questions, q)
	}

	return api.GetWrongAnswers200JSONResponse{
		Questions: questions,
		Total:     int(total),
	}, nil
}
