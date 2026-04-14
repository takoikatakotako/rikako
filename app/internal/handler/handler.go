package handler

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/db"
	"github.com/takoikatakotako/rikako/internal/identity"
)

type Handler struct {
	queries          *db.Queries
	imageBaseURL     string
	logger           *slog.Logger
	identityProvider identity.Provider
}

func New(d *sql.DB, imageBaseURL string, logger *slog.Logger, identityProvider identity.Provider) *Handler {
	return &Handler{
		queries:          db.New(d),
		imageBaseURL:     imageBaseURL,
		logger:           logger,
		identityProvider: identityProvider,
	}
}

func validatePagination(limit, offset *int) (int, int, error) {
	l, o := 20, 0
	if limit != nil {
		l = *limit
	}
	if offset != nil {
		o = *offset
	}
	if l < 1 || l > 100 {
		return 0, 0, fmt.Errorf("limit must be between 1 and 100")
	}
	if o < 0 {
		return 0, 0, fmt.Errorf("offset must be >= 0")
	}
	return l, o, nil
}

func (h *Handler) Root(ctx context.Context, request api.RootRequestObject) (api.RootResponseObject, error) {
	return api.Root200JSONResponse{
		Message: "running",
	}, nil
}

func (h *Handler) HealthCheck(ctx context.Context, request api.HealthCheckRequestObject) (api.HealthCheckResponseObject, error) {
	return api.HealthCheck200JSONResponse{
		Status: "ok",
	}, nil
}

// questionWithChoicesRow is a common interface for flat rows containing question + choice data.
type questionWithChoicesRow struct {
	ID          int64
	Text        string
	Explanation sql.NullString
	ChoiceText  sql.NullString
	IsCorrect   sql.NullBool
	ChoiceIndex sql.NullInt32
}

// buildQuestionsFromRows groups flat question+choice rows into api.Question slices.
// It preserves the row order for question ordering.
func buildQuestionsFromRows(rows []questionWithChoicesRow) []api.Question {
	type questionData struct {
		id          int64
		text        string
		explanation sql.NullString
		choices     []string
		correct     int
	}

	var ordered []int64
	qmap := map[int64]*questionData{}

	for _, row := range rows {
		qd, exists := qmap[row.ID]
		if !exists {
			qd = &questionData{
				id:          row.ID,
				text:        row.Text,
				explanation: row.Explanation,
			}
			qmap[row.ID] = qd
			ordered = append(ordered, row.ID)
		}
		if row.ChoiceText.Valid {
			// Expand choices slice to fit choice_index
			idx := int(row.ChoiceIndex.Int32)
			for len(qd.choices) <= idx {
				qd.choices = append(qd.choices, "")
			}
			qd.choices[idx] = row.ChoiceText.String
			if row.IsCorrect.Valid && row.IsCorrect.Bool {
				qd.correct = idx
			}
		}
	}

	questions := make([]api.Question, 0, len(ordered))
	for _, id := range ordered {
		qd := qmap[id]
		q := api.Question{
			Id:      qd.id,
			Type:    api.SingleChoice,
			Text:    qd.text,
			Choices: qd.choices,
			Correct: &qd.correct,
		}
		if qd.explanation.Valid {
			q.Explanation = &qd.explanation.String
		}
		questions = append(questions, q)
	}
	return questions
}

// attachImages fetches image URLs for the given questions in a single batch query and attaches them.
func (h *Handler) attachImages(ctx context.Context, questions []api.Question) error {
	if len(questions) == 0 {
		return nil
	}

	ids := make([]int64, len(questions))
	for i, q := range questions {
		ids[i] = q.Id
	}

	imageRows, err := h.queries.GetImageURLsByQuestionIDs(ctx, ids)
	if err != nil {
		return err
	}

	// Group by question_id
	imageMap := map[int64][]string{}
	for _, row := range imageRows {
		imageMap[row.QuestionID] = append(imageMap[row.QuestionID],
			fmt.Sprintf("%s/%s", h.imageBaseURL, row.Path))
	}

	for i := range questions {
		if urls, ok := imageMap[questions[i].Id]; ok {
			questions[i].Images = &urls
		}
	}
	return nil
}

// buildQuestion builds a single api.Question (used for single-item endpoints like GetQuestion).
func (h *Handler) buildQuestion(ctx context.Context, id int64, text string, explanation sql.NullString) (api.Question, error) {
	choiceRows, err := h.queries.GetChoicesByQuestionID(ctx, id)
	if err != nil {
		return api.Question{}, err
	}

	var choices []string
	var correct int
	for _, c := range choiceRows {
		choices = append(choices, c.Text)
		if c.IsCorrect {
			correct = int(c.ChoiceIndex)
		}
	}

	q := api.Question{
		Id:      id,
		Type:    api.SingleChoice,
		Text:    text,
		Choices: choices,
		Correct: &correct,
	}
	if explanation.Valid {
		q.Explanation = &explanation.String
	}

	paths, err := h.queries.GetImageURLsByQuestionID(ctx, id)
	if err != nil {
		return api.Question{}, err
	}
	if len(paths) > 0 {
		urls := make([]string, len(paths))
		for i, p := range paths {
			urls[i] = fmt.Sprintf("%s/%s", h.imageBaseURL, p)
		}
		q.Images = &urls
	}

	return q, nil
}

func (h *Handler) GetQuestions(ctx context.Context, request api.GetQuestionsRequestObject) (api.GetQuestionsResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetQuestions400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	total, err := h.queries.CountQuestions(ctx)
	if err != nil {
		h.logger.Error("failed to count questions", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListQuestionsWithChoices(ctx, db.ListQuestionsWithChoicesParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to query questions", "error", err)
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

	return api.GetQuestions200JSONResponse{
		Questions: questions,
		Total:     int(total),
	}, nil
}

func (h *Handler) GetQuestion(ctx context.Context, request api.GetQuestionRequestObject) (api.GetQuestionResponseObject, error) {
	row, err := h.queries.GetQuestionByID(ctx, request.QuestionId)
	if err == sql.ErrNoRows {
		return api.GetQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to query question", "error", err, "question_id", request.QuestionId)
		return nil, err
	}

	q, err := h.buildQuestion(ctx, row.ID, row.Text, row.Explanation)
	if err != nil {
		h.logger.Error("failed to build question", "error", err, "question_id", row.ID)
		return nil, err
	}

	return api.GetQuestion200JSONResponse(q), nil
}

func (h *Handler) GetCategories(ctx context.Context, request api.GetCategoriesRequestObject) (api.GetCategoriesResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetCategories400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	total, err := h.queries.CountCategories(ctx)
	if err != nil {
		h.logger.Error("failed to count categories", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListCategories(ctx, db.ListCategoriesParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to query categories", "error", err)
		return nil, err
	}

	categories := []api.Category{}
	for _, row := range rows {
		wc := int(row.WorkbookCount)
		c := api.Category{
			Id:            row.ID,
			Title:         row.Title,
			WorkbookCount: &wc,
		}
		if row.Description.Valid {
			c.Description = &row.Description.String
		}
		categories = append(categories, c)
	}

	return api.GetCategories200JSONResponse{
		Categories: categories,
		Total:      int(total),
	}, nil
}

func (h *Handler) GetCategory(ctx context.Context, request api.GetCategoryRequestObject) (api.GetCategoryResponseObject, error) {
	cat, err := h.queries.GetCategoryByID(ctx, request.CategoryId)
	if err == sql.ErrNoRows {
		return api.GetCategory404JSONResponse{Code: "NOT_FOUND", Message: "category not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to query category", "error", err, "category_id", request.CategoryId)
		return nil, err
	}

	wbRows, err := h.queries.ListWorkbooksByCategory(ctx, sql.NullInt64{Int64: cat.ID, Valid: true})
	if err != nil {
		h.logger.Error("failed to query category workbooks", "error", err, "category_id", cat.ID)
		return nil, err
	}

	workbooks := []api.Workbook{}
	for _, row := range wbRows {
		qc := int(row.QuestionCount)
		w := api.Workbook{
			Id:            row.ID,
			Title:         row.Title,
			QuestionCount: &qc,
			CategoryId:    &cat.ID,
		}
		if row.Description.Valid {
			w.Description = &row.Description.String
		}
		workbooks = append(workbooks, w)
	}

	c := api.CategoryDetail{
		Id:        cat.ID,
		Title:     cat.Title,
		Workbooks: workbooks,
	}
	if cat.Description.Valid {
		c.Description = &cat.Description.String
	}

	return api.GetCategory200JSONResponse(c), nil
}

func (h *Handler) GetWorkbooks(ctx context.Context, request api.GetWorkbooksRequestObject) (api.GetWorkbooksResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetWorkbooks400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	total, err := h.queries.CountWorkbooks(ctx)
	if err != nil {
		h.logger.Error("failed to count workbooks", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListWorkbooks(ctx, db.ListWorkbooksParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to query workbooks", "error", err)
		return nil, err
	}

	workbooks := []api.Workbook{}
	for _, row := range rows {
		qc := int(row.QuestionCount)
		w := api.Workbook{
			Id:            row.ID,
			Title:         row.Title,
			QuestionCount: &qc,
		}
		if row.Description.Valid {
			w.Description = &row.Description.String
		}
		if row.CategoryID.Valid {
			cid := row.CategoryID.Int64
			w.CategoryId = &cid
		}
		workbooks = append(workbooks, w)
	}

	return api.GetWorkbooks200JSONResponse{
		Workbooks: workbooks,
		Total:     int(total),
	}, nil
}

func (h *Handler) GetWorkbook(ctx context.Context, request api.GetWorkbookRequestObject) (api.GetWorkbookResponseObject, error) {
	wb, err := h.queries.GetWorkbookByID(ctx, request.WorkbookId)
	if err == sql.ErrNoRows {
		return api.GetWorkbook404JSONResponse{Code: "NOT_FOUND", Message: "workbook not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to query workbook", "error", err, "workbook_id", request.WorkbookId)
		return nil, err
	}

	qRows, err := h.queries.ListQuestionsWithChoicesByWorkbook(ctx, wb.ID)
	if err != nil {
		h.logger.Error("failed to query workbook questions", "error", err, "workbook_id", wb.ID)
		return nil, err
	}

	flatRows := make([]questionWithChoicesRow, len(qRows))
	for i, r := range qRows {
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

	w := api.WorkbookDetail{
		Id:        wb.ID,
		Title:     wb.Title,
		Questions: questions,
	}
	if wb.Description.Valid {
		w.Description = &wb.Description.String
	}
	if wb.CategoryID.Valid {
		cid := wb.CategoryID.Int64
		w.CategoryId = &cid
	}

	return api.GetWorkbook200JSONResponse(w), nil
}
