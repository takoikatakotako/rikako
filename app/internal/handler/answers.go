package handler

import (
	"context"
	"database/sql"
	"time"

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

func (h *Handler) GetWorkbookProgress(ctx context.Context, request api.GetWorkbookProgressRequestObject) (api.GetWorkbookProgressResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.GetWorkbookProgress400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}
	if request.Params.WorkbookId == 0 {
		return api.GetWorkbookProgress400JSONResponse{Code: "INVALID_PARAMETER", Message: "workbook_id is required"}, nil
	}

	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if err == sql.ErrNoRows {
		return api.GetWorkbookProgress200JSONResponse{Results: []api.QuestionProgressItem{}}, nil
	}
	if err != nil {
		h.logger.Error("failed to get user", "error", err, "device_id", deviceID)
		return nil, err
	}

	rows, err := h.queries.ListWorkbookProgress(ctx, db.ListWorkbookProgressParams{
		UserID:     userID,
		WorkbookID: request.Params.WorkbookId,
	})
	if err != nil {
		h.logger.Error("failed to query workbook progress", "error", err)
		return nil, err
	}

	results := make([]api.QuestionProgressItem, len(rows))
	for i, r := range rows {
		results[i] = api.QuestionProgressItem{
			QuestionId: r.QuestionID,
			IsCorrect:  r.IsCorrect,
		}
	}

	return api.GetWorkbookProgress200JSONResponse{Results: results}, nil
}

func (h *Handler) GetUserSummary(ctx context.Context, request api.GetUserSummaryRequestObject) (api.GetUserSummaryResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.GetUserSummary400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if err == sql.ErrNoRows {
		return api.GetUserSummary200JSONResponse{
			TotalAnswered: 0, TotalCorrect: 0,
			WeeklyAnswered: 0, WeeklyCorrect: 0,
			StudyDates: []string{}, WeeklyWorkbookIds: []int64{},
		}, nil
	}
	if err != nil {
		h.logger.Error("failed to get user", "error", err, "device_id", deviceID)
		return nil, err
	}

	weekStart := isoWeekStart(time.Now())

	totalStats, err := h.queries.GetUserTotalStats(ctx, userID)
	if err != nil {
		h.logger.Error("failed to get total stats", "error", err)
		return nil, err
	}

	weeklyStats, err := h.queries.GetUserWeeklyStats(ctx, db.GetUserWeeklyStatsParams{
		UserID:     userID,
		AnsweredAt: sql.NullTime{Time: weekStart, Valid: true},
	})
	if err != nil {
		h.logger.Error("failed to get weekly stats", "error", err)
		return nil, err
	}

	studyDateRows, err := h.queries.ListStudyDates(ctx, userID)
	if err != nil {
		h.logger.Error("failed to list study dates", "error", err)
		return nil, err
	}

	weeklyWorkbookRows, err := h.queries.ListWeeklyWorkbookIDs(ctx, db.ListWeeklyWorkbookIDsParams{
		UserID:     userID,
		AnsweredAt: sql.NullTime{Time: weekStart, Valid: true},
	})
	if err != nil {
		h.logger.Error("failed to list weekly workbook ids", "error", err)
		return nil, err
	}

	studyDates := make([]string, len(studyDateRows))
	for i, d := range studyDateRows {
		studyDates[i] = d
	}

	weeklyWorkbookIDs := make([]int64, len(weeklyWorkbookRows))
	for i, id := range weeklyWorkbookRows {
		weeklyWorkbookIDs[i] = id
	}

	return api.GetUserSummary200JSONResponse{
		TotalAnswered:     int(totalStats.TotalAnswered),
		TotalCorrect:      int(totalStats.TotalCorrect),
		WeeklyAnswered:    int(weeklyStats.WeeklyAnswered),
		WeeklyCorrect:     int(weeklyStats.WeeklyCorrect),
		StudyDates:        studyDates,
		WeeklyWorkbookIds: weeklyWorkbookIDs,
	}, nil
}

// isoWeekStart returns Monday 00:00:00 JST (= Sunday 15:00:00 UTC) of the ISO week containing t.
func isoWeekStart(t time.Time) time.Time {
	jst := time.FixedZone("Asia/Tokyo", 9*60*60)
	t = t.In(jst)
	weekday := int(t.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	monday := time.Date(t.Year(), t.Month(), t.Day()-weekday+1, 0, 0, 0, 0, jst)
	return monday.UTC()
}

func (h *Handler) GetAnswerLogs(ctx context.Context, request api.GetAnswerLogsRequestObject) (api.GetAnswerLogsResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.GetAnswerLogs400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetAnswerLogs400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if err == sql.ErrNoRows {
		return api.GetAnswerLogs200JSONResponse{Logs: []api.AnswerLogItem{}, Total: 0}, nil
	}
	if err != nil {
		h.logger.Error("failed to get user", "error", err, "device_id", deviceID)
		return nil, err
	}

	total, err := h.queries.CountUserAnswerLogs(ctx, userID)
	if err != nil {
		h.logger.Error("failed to count answer logs", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListUserAnswerLogs(ctx, db.ListUserAnswerLogsParams{
		UserID: userID,
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to query answer logs", "error", err)
		return nil, err
	}

	logs := make([]api.AnswerLogItem, len(rows))
	for i, r := range rows {
		logs[i] = api.AnswerLogItem{
			Id:             r.ID,
			QuestionId:     r.QuestionID,
			QuestionText:   r.QuestionText,
			WorkbookId:     r.WorkbookID,
			WorkbookTitle:  r.WorkbookTitle,
			SelectedChoice: int(r.SelectedChoice),
			IsCorrect:      r.IsCorrect,
			AnsweredAt:     r.AnsweredAt.Time,
		}
	}

	return api.GetAnswerLogs200JSONResponse{Logs: logs, Total: int(total)}, nil
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
