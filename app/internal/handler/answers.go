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

	// Batch fetch correct choices for all question IDs (1 query instead of N)
	questionIDs := make([]int64, len(request.Body.Answers))
	for i, a := range request.Body.Answers {
		questionIDs[i] = a.QuestionId
	}
	correctRows, err := h.queries.GetCorrectChoicesByQuestionIDs(ctx, questionIDs)
	if err != nil {
		h.logger.Error("failed to batch check answers", "error", err)
		return nil, err
	}
	correctMap := map[int64]int32{}
	for _, row := range correctRows {
		correctMap[row.QuestionID] = row.ChoiceIndex
	}

	correctCount := 0
	for _, answer := range request.Body.Answers {
		isCorrect := correctMap[answer.QuestionId] == int32(answer.SelectedChoice)
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

	rows, err := h.queries.ListWrongAnswersWithChoices(ctx, db.ListWrongAnswersWithChoicesParams{
		UserID: userID,
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to query wrong answers", "error", err)
		return nil, err
	}

	flatRows := make([]questionWithChoicesRow, len(rows))
	for i, r := range rows {
		flatRows[i] = questionWithChoicesRow{
			ID: r.ID, Text: r.Text, Explanation: r.Explanation,
			ChoiceText: r.ChoiceText, IsCorrect: r.IsCorrect, ChoiceIndex: r.ChoiceIndex,
		}
	}
	questions := buildQuestionsFromRows(flatRows)
	if err := h.attachImages(ctx, questions); err != nil {
		h.logger.Error("failed to attach images", "error", err)
		return nil, err
	}

	return api.GetWrongAnswers200JSONResponse{
		Questions: questions,
		Total:     int(total),
	}, nil
}
