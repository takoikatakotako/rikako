package admin

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
	"github.com/takoikatakotako/rikako/internal/adminapi"
	"github.com/takoikatakotako/rikako/internal/db"
)

type Handler struct {
	sqlDB           *sql.DB
	queries         *db.Queries
	imageBaseURL    string
	s3Client        *s3.Client
	s3Bucket        string
	contentS3Bucket string
	logger          *slog.Logger
}

func New(d *sql.DB, imageBaseURL string, s3Client *s3.Client, s3Bucket string, contentS3Bucket string, logger *slog.Logger) *Handler {
	return &Handler{
		sqlDB:           d,
		queries:         db.New(d),
		imageBaseURL:    imageBaseURL,
		s3Client:        s3Client,
		s3Bucket:        s3Bucket,
		contentS3Bucket: contentS3Bucket,
		logger:          logger,
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

func (h *Handler) Root(_ context.Context, _ adminapi.RootRequestObject) (adminapi.RootResponseObject, error) {
	return adminapi.Root200JSONResponse{Message: "admin api running"}, nil
}

func (h *Handler) HealthCheck(_ context.Context, _ adminapi.HealthCheckRequestObject) (adminapi.HealthCheckResponseObject, error) {
	return adminapi.HealthCheck200JSONResponse{Status: "ok"}, nil
}

// getImageURLs returns image URLs for a given question ID.
func (h *Handler) getImageURLs(ctx context.Context, questionID int64) ([]string, error) {
	paths, err := h.queries.GetImageURLsByQuestionID(ctx, questionID)
	if err != nil {
		return nil, err
	}
	var urls []string
	for _, path := range paths {
		urls = append(urls, fmt.Sprintf("%s/%s", h.imageBaseURL, path))
	}
	return urls, nil
}

// getQuestionByID fetches a full question with choices and images.
func (h *Handler) getQuestionByID(ctx context.Context, questionID int64) (*adminapi.Question, error) {
	row, err := h.queries.GetQuestionByID(ctx, questionID)
	if err != nil {
		return nil, err
	}

	choiceRows, err := h.queries.GetChoicesByQuestionID(ctx, questionID)
	if err != nil {
		return nil, err
	}

	var choices []adminapi.Choice
	for _, c := range choiceRows {
		choices = append(choices, adminapi.Choice{Text: c.Text, IsCorrect: c.IsCorrect})
	}

	q := &adminapi.Question{
		Id:      row.ID,
		Type:    adminapi.QuestionTypeSingleChoice,
		Text:    row.Text,
		Choices: choices,
	}
	if row.Explanation.Valid {
		q.Explanation = &row.Explanation.String
	}

	imageURLs, err := h.getImageURLs(ctx, row.ID)
	if err != nil {
		return nil, err
	}
	if len(imageURLs) > 0 {
		q.Images = &imageURLs
	}

	return q, nil
}

// --- Categories CRUD ---

func (h *Handler) GetCategories(ctx context.Context, request adminapi.GetCategoriesRequestObject) (adminapi.GetCategoriesResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return adminapi.GetCategories400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
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

	categories := []adminapi.Category{}
	for _, row := range rows {
		wc := int(row.WorkbookCount)
		c := adminapi.Category{
			Id:            row.ID,
			Title:         row.Title,
			WorkbookCount: &wc,
		}
		if row.Description.Valid {
			c.Description = &row.Description.String
		}
		categories = append(categories, c)
	}

	return adminapi.GetCategories200JSONResponse{Categories: categories, Total: int(total)}, nil
}

// getCategoryDetail fetches a category with its workbooks.
func (h *Handler) getCategoryDetail(ctx context.Context, categoryID int64) (*adminapi.CategoryDetail, error) {
	cat, err := h.queries.GetCategoryByID(ctx, categoryID)
	if err != nil {
		return nil, err
	}

	wbRows, err := h.queries.ListWorkbooksByCategory(ctx, sql.NullInt64{Int64: cat.ID, Valid: true})
	if err != nil {
		return nil, err
	}

	workbooks := []adminapi.Workbook{}
	for _, row := range wbRows {
		qc := int(row.QuestionCount)
		w := adminapi.Workbook{
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

	c := &adminapi.CategoryDetail{
		Id:        cat.ID,
		Title:     cat.Title,
		Workbooks: workbooks,
	}
	if cat.Description.Valid {
		c.Description = &cat.Description.String
	}
	return c, nil
}

func (h *Handler) GetCategory(ctx context.Context, request adminapi.GetCategoryRequestObject) (adminapi.GetCategoryResponseObject, error) {
	c, err := h.getCategoryDetail(ctx, request.CategoryId)
	if err == sql.ErrNoRows {
		return adminapi.GetCategory404JSONResponse{Code: "NOT_FOUND", Message: "category not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get category", "error", err, "category_id", request.CategoryId)
		return nil, err
	}
	return adminapi.GetCategory200JSONResponse(*c), nil
}

func (h *Handler) CreateCategory(ctx context.Context, request adminapi.CreateCategoryRequestObject) (adminapi.CreateCategoryResponseObject, error) {
	body := request.Body

	desc := sql.NullString{}
	if body.Description != nil {
		desc = sql.NullString{String: *body.Description, Valid: true}
	}
	categoryID, err := h.queries.CreateCategory(ctx, db.CreateCategoryParams{
		Title:       body.Title,
		Description: desc,
	})
	if err != nil {
		h.logger.Error("failed to insert category", "error", err)
		return nil, err
	}

	c, err := h.getCategoryDetail(ctx, categoryID)
	if err != nil {
		h.logger.Error("failed to get created category", "error", err)
		return nil, err
	}

	return adminapi.CreateCategory201JSONResponse(*c), nil
}

func (h *Handler) UpdateCategory(ctx context.Context, request adminapi.UpdateCategoryRequestObject) (adminapi.UpdateCategoryResponseObject, error) {
	body := request.Body

	exists, err := h.queries.CategoryExists(ctx, request.CategoryId)
	if err != nil {
		h.logger.Error("failed to check category existence", "error", err)
		return nil, err
	}
	if !exists {
		return adminapi.UpdateCategory404JSONResponse{Code: "NOT_FOUND", Message: "category not found"}, nil
	}

	desc := sql.NullString{}
	if body.Description != nil {
		desc = sql.NullString{String: *body.Description, Valid: true}
	}
	err = h.queries.UpdateCategory(ctx, db.UpdateCategoryParams{
		Title:       body.Title,
		Description: desc,
		UpdatedAt:   sql.NullTime{Time: time.Now(), Valid: true},
		ID:          request.CategoryId,
	})
	if err != nil {
		h.logger.Error("failed to update category", "error", err)
		return nil, err
	}

	c, err := h.getCategoryDetail(ctx, request.CategoryId)
	if err != nil {
		h.logger.Error("failed to get updated category", "error", err)
		return nil, err
	}

	return adminapi.UpdateCategory200JSONResponse(*c), nil
}

func (h *Handler) DeleteCategory(ctx context.Context, request adminapi.DeleteCategoryRequestObject) (adminapi.DeleteCategoryResponseObject, error) {
	result, err := h.queries.DeleteCategory(ctx, request.CategoryId)
	if err != nil {
		h.logger.Error("failed to delete category", "error", err, "category_id", request.CategoryId)
		return nil, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, err
	}
	if rowsAffected == 0 {
		return adminapi.DeleteCategory404JSONResponse{Code: "NOT_FOUND", Message: "category not found"}, nil
	}

	return adminapi.DeleteCategory204Response{}, nil
}

// --- Questions CRUD ---

func (h *Handler) GetQuestions(ctx context.Context, request adminapi.GetQuestionsRequestObject) (adminapi.GetQuestionsResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return adminapi.GetQuestions400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
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

	type questionData struct {
		question adminapi.Question
	}

	questionsMap := map[int64]*questionData{}
	questionOrder := make([]int64, 0)

	for _, row := range rows {
		qd, exists := questionsMap[row.ID]
		if !exists {
			q := adminapi.Question{
				Id:   row.ID,
				Type: adminapi.QuestionTypeSingleChoice,
				Text: row.Text,
			}
			if row.Explanation.Valid {
				q.Explanation = &row.Explanation.String
			}
			qd = &questionData{question: q}
			questionsMap[row.ID] = qd
			questionOrder = append(questionOrder, row.ID)
		}

		if row.ChoiceText.Valid {
			qd.question.Choices = append(qd.question.Choices, adminapi.Choice{
				Text:      row.ChoiceText.String,
				IsCorrect: row.IsCorrect.Valid && row.IsCorrect.Bool,
			})
		}
	}

	if len(questionOrder) > 0 {
		imageRows, err := h.queries.GetImageURLsByQuestionIDs(ctx, questionOrder)
		if err != nil {
			h.logger.Error("failed to get question images", "error", err)
			return nil, err
		}

		for _, imageRow := range imageRows {
			if qd, ok := questionsMap[imageRow.QuestionID]; ok {
				url := fmt.Sprintf("%s/%s", h.imageBaseURL, imageRow.Path)
				if qd.question.Images == nil {
					urls := []string{url}
					qd.question.Images = &urls
				} else {
					*qd.question.Images = append(*qd.question.Images, url)
				}
			}
		}
	}

	questions := make([]adminapi.Question, 0, len(questionOrder))
	for _, questionID := range questionOrder {
		if qd, ok := questionsMap[questionID]; ok {
			questions = append(questions, qd.question)
		}
	}

	return adminapi.GetQuestions200JSONResponse{Questions: questions, Total: int(total)}, nil
}

func (h *Handler) GetQuestion(ctx context.Context, request adminapi.GetQuestionRequestObject) (adminapi.GetQuestionResponseObject, error) {
	q, err := h.getQuestionByID(ctx, request.QuestionId)
	if err == sql.ErrNoRows {
		return adminapi.GetQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get question", "error", err, "question_id", request.QuestionId)
		return nil, err
	}
	return adminapi.GetQuestion200JSONResponse(*q), nil
}

func (h *Handler) CreateQuestion(ctx context.Context, request adminapi.CreateQuestionRequestObject) (adminapi.CreateQuestionResponseObject, error) {
	body := request.Body
	if len(body.Choices) < 2 {
		return adminapi.CreateQuestion400JSONResponse{Code: "INVALID_PARAMETER", Message: "at least 2 choices required"}, nil
	}

	hasCorrect := false
	for _, c := range body.Choices {
		if c.IsCorrect {
			hasCorrect = true
			break
		}
	}
	if !hasCorrect {
		return adminapi.CreateQuestion400JSONResponse{Code: "INVALID_PARAMETER", Message: "at least one choice must be correct"}, nil
	}

	tx, err := h.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	qtx := h.queries.WithTx(tx)

	questionID, err := qtx.CreateQuestion(ctx, string(body.Type))
	if err != nil {
		h.logger.Error("failed to insert question", "error", err)
		return nil, err
	}

	explanationArg := sql.NullString{}
	if body.Explanation != nil {
		explanationArg = sql.NullString{String: *body.Explanation, Valid: true}
	}
	singleChoiceID, err := qtx.CreateSingleChoice(ctx, db.CreateSingleChoiceParams{
		QuestionID:  questionID,
		Text:        body.Text,
		Explanation: explanationArg,
	})
	if err != nil {
		h.logger.Error("failed to insert single choice", "error", err)
		return nil, err
	}

	for i, c := range body.Choices {
		err = qtx.CreateChoice(ctx, db.CreateChoiceParams{
			SingleChoiceID: singleChoiceID,
			ChoiceIndex:    int32(i),
			Text:           c.Text,
			IsCorrect:      c.IsCorrect,
		})
		if err != nil {
			h.logger.Error("failed to insert choice", "error", err)
			return nil, err
		}
	}

	if body.ImageIds != nil {
		for i, imageID := range *body.ImageIds {
			err = qtx.CreateQuestionImage(ctx, db.CreateQuestionImageParams{
				QuestionID: questionID,
				ImageID:    imageID,
				OrderIndex: int32(i),
			})
			if err != nil {
				h.logger.Error("failed to insert question image", "error", err, "image_id", imageID)
				return nil, err
			}
		}
	}

	if err := tx.Commit(); err != nil {
		h.logger.Error("failed to commit transaction", "error", err)
		return nil, err
	}

	q, err := h.getQuestionByID(ctx, questionID)
	if err != nil {
		h.logger.Error("failed to get created question", "error", err)
		return nil, err
	}

	return adminapi.CreateQuestion201JSONResponse(*q), nil
}

func (h *Handler) UpdateQuestion(ctx context.Context, request adminapi.UpdateQuestionRequestObject) (adminapi.UpdateQuestionResponseObject, error) {
	body := request.Body
	if len(body.Choices) < 2 {
		return adminapi.UpdateQuestion400JSONResponse{Code: "INVALID_PARAMETER", Message: "at least 2 choices required"}, nil
	}

	hasCorrect := false
	for _, c := range body.Choices {
		if c.IsCorrect {
			hasCorrect = true
			break
		}
	}
	if !hasCorrect {
		return adminapi.UpdateQuestion400JSONResponse{Code: "INVALID_PARAMETER", Message: "at least one choice must be correct"}, nil
	}

	tx, err := h.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	qtx := h.queries.WithTx(tx)

	exists, err := qtx.QuestionExists(ctx, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to check question existence", "error", err)
		return nil, err
	}
	if !exists {
		return adminapi.UpdateQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}

	explanationArg := sql.NullString{}
	if body.Explanation != nil {
		explanationArg = sql.NullString{String: *body.Explanation, Valid: true}
	}
	err = qtx.UpdateSingleChoice(ctx, db.UpdateSingleChoiceParams{
		Text:        body.Text,
		Explanation: explanationArg,
		UpdatedAt:   sql.NullTime{Time: time.Now(), Valid: true},
		QuestionID:  request.QuestionId,
	})
	if err != nil {
		h.logger.Error("failed to update single choice", "error", err)
		return nil, err
	}

	err = qtx.DeleteChoicesByQuestionID(ctx, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to delete old choices", "error", err)
		return nil, err
	}

	singleChoiceID, err := qtx.GetSingleChoiceID(ctx, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to get single choice id", "error", err)
		return nil, err
	}

	for i, c := range body.Choices {
		err = qtx.CreateChoice(ctx, db.CreateChoiceParams{
			SingleChoiceID: singleChoiceID,
			ChoiceIndex:    int32(i),
			Text:           c.Text,
			IsCorrect:      c.IsCorrect,
		})
		if err != nil {
			h.logger.Error("failed to insert choice", "error", err)
			return nil, err
		}
	}

	err = qtx.DeleteQuestionImages(ctx, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to delete old question images", "error", err)
		return nil, err
	}
	if body.ImageIds != nil {
		for i, imageID := range *body.ImageIds {
			err = qtx.CreateQuestionImage(ctx, db.CreateQuestionImageParams{
				QuestionID: request.QuestionId,
				ImageID:    imageID,
				OrderIndex: int32(i),
			})
			if err != nil {
				h.logger.Error("failed to insert question image", "error", err, "image_id", imageID)
				return nil, err
			}
		}
	}

	err = qtx.UpdateQuestionTimestamp(ctx, db.UpdateQuestionTimestampParams{
		UpdatedAt: sql.NullTime{Time: time.Now(), Valid: true},
		ID:        request.QuestionId,
	})
	if err != nil {
		h.logger.Error("failed to update question timestamp", "error", err)
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		h.logger.Error("failed to commit transaction", "error", err)
		return nil, err
	}

	q, err := h.getQuestionByID(ctx, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to get updated question", "error", err)
		return nil, err
	}

	return adminapi.UpdateQuestion200JSONResponse(*q), nil
}

func (h *Handler) DeleteQuestion(ctx context.Context, request adminapi.DeleteQuestionRequestObject) (adminapi.DeleteQuestionResponseObject, error) {
	result, err := h.queries.DeleteQuestion(ctx, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to delete question", "error", err, "question_id", request.QuestionId)
		return nil, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, err
	}
	if rowsAffected == 0 {
		return adminapi.DeleteQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}

	return adminapi.DeleteQuestion204Response{}, nil
}

// --- Workbooks CRUD ---

func (h *Handler) GetWorkbooks(ctx context.Context, request adminapi.GetWorkbooksRequestObject) (adminapi.GetWorkbooksResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return adminapi.GetWorkbooks400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
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

	workbooks := []adminapi.Workbook{}
	for _, row := range rows {
		qc := int(row.QuestionCount)
		w := adminapi.Workbook{
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

	return adminapi.GetWorkbooks200JSONResponse{Workbooks: workbooks, Total: int(total)}, nil
}

// getWorkbookDetail fetches a workbook with its questions.
func (h *Handler) getWorkbookDetail(ctx context.Context, workbookID int64) (*adminapi.WorkbookDetail, error) {
	wb, err := h.queries.GetWorkbookByID(ctx, workbookID)
	if err != nil {
		return nil, err
	}

	rows, err := h.queries.ListQuestionsWithChoicesByWorkbook(ctx, wb.ID)
	if err != nil {
		return nil, err
	}

	type questionData struct {
		question adminapi.Question
	}

	questionsMap := map[int64]*questionData{}
	questionOrder := make([]int64, 0)

	for _, row := range rows {
		qd, exists := questionsMap[row.ID]
		if !exists {
			q := adminapi.Question{
				Id:   row.ID,
				Type: adminapi.QuestionTypeSingleChoice,
				Text: row.Text,
			}
			if row.Explanation.Valid {
				q.Explanation = &row.Explanation.String
			}
			qd = &questionData{question: q}
			questionsMap[row.ID] = qd
			questionOrder = append(questionOrder, row.ID)
		}

		if row.ChoiceText.Valid {
			qd.question.Choices = append(qd.question.Choices, adminapi.Choice{
				Text:      row.ChoiceText.String,
				IsCorrect: row.IsCorrect.Valid && row.IsCorrect.Bool,
			})
		}
	}

	if len(questionOrder) > 0 {
		imageRows, err := h.queries.GetImageURLsByQuestionIDs(ctx, questionOrder)
		if err != nil {
			return nil, err
		}

		for _, imageRow := range imageRows {
			if qd, ok := questionsMap[imageRow.QuestionID]; ok {
				url := fmt.Sprintf("%s/%s", h.imageBaseURL, imageRow.Path)
				if qd.question.Images == nil {
					urls := []string{url}
					qd.question.Images = &urls
				} else {
					*qd.question.Images = append(*qd.question.Images, url)
				}
			}
		}
	}

	questions := make([]adminapi.Question, 0, len(questionOrder))
	for _, questionID := range questionOrder {
		if qd, ok := questionsMap[questionID]; ok {
			questions = append(questions, qd.question)
		}
	}

	w := &adminapi.WorkbookDetail{
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
	return w, nil
}

func (h *Handler) GetWorkbook(ctx context.Context, request adminapi.GetWorkbookRequestObject) (adminapi.GetWorkbookResponseObject, error) {
	w, err := h.getWorkbookDetail(ctx, request.WorkbookId)
	if err == sql.ErrNoRows {
		return adminapi.GetWorkbook404JSONResponse{Code: "NOT_FOUND", Message: "workbook not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get workbook", "error", err, "workbook_id", request.WorkbookId)
		return nil, err
	}
	return adminapi.GetWorkbook200JSONResponse(*w), nil
}

func (h *Handler) CreateWorkbook(ctx context.Context, request adminapi.CreateWorkbookRequestObject) (adminapi.CreateWorkbookResponseObject, error) {
	body := request.Body

	tx, err := h.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	qtx := h.queries.WithTx(tx)

	desc := sql.NullString{}
	if body.Description != nil {
		desc = sql.NullString{String: *body.Description, Valid: true}
	}
	catID := sql.NullInt64{}
	if body.CategoryId != nil {
		catID = sql.NullInt64{Int64: *body.CategoryId, Valid: true}
	}
	workbookID, err := qtx.CreateWorkbook(ctx, db.CreateWorkbookParams{
		Title:       body.Title,
		Description: desc,
		CategoryID:  catID,
	})
	if err != nil {
		h.logger.Error("failed to insert workbook", "error", err)
		return nil, err
	}

	if body.QuestionIds != nil {
		for i, qID := range *body.QuestionIds {
			err = qtx.CreateWorkbookQuestion(ctx, db.CreateWorkbookQuestionParams{
				WorkbookID: workbookID,
				QuestionID: qID,
				OrderIndex: int32(i),
			})
			if err != nil {
				h.logger.Error("failed to insert workbook question", "error", err, "question_id", qID)
				return nil, err
			}
		}
	}

	if err := tx.Commit(); err != nil {
		h.logger.Error("failed to commit transaction", "error", err)
		return nil, err
	}

	w, err := h.getWorkbookDetail(ctx, workbookID)
	if err != nil {
		h.logger.Error("failed to get created workbook", "error", err)
		return nil, err
	}

	return adminapi.CreateWorkbook201JSONResponse(*w), nil
}

func (h *Handler) UpdateWorkbook(ctx context.Context, request adminapi.UpdateWorkbookRequestObject) (adminapi.UpdateWorkbookResponseObject, error) {
	body := request.Body

	tx, err := h.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	qtx := h.queries.WithTx(tx)

	exists, err := qtx.WorkbookExists(ctx, request.WorkbookId)
	if err != nil {
		h.logger.Error("failed to check workbook existence", "error", err)
		return nil, err
	}
	if !exists {
		return adminapi.UpdateWorkbook404JSONResponse{Code: "NOT_FOUND", Message: "workbook not found"}, nil
	}

	desc := sql.NullString{}
	if body.Description != nil {
		desc = sql.NullString{String: *body.Description, Valid: true}
	}
	catID := sql.NullInt64{}
	if body.CategoryId != nil {
		catID = sql.NullInt64{Int64: *body.CategoryId, Valid: true}
	}
	err = qtx.UpdateWorkbook(ctx, db.UpdateWorkbookParams{
		Title:       body.Title,
		Description: desc,
		CategoryID:  catID,
		UpdatedAt:   sql.NullTime{Time: time.Now(), Valid: true},
		ID:          request.WorkbookId,
	})
	if err != nil {
		h.logger.Error("failed to update workbook", "error", err)
		return nil, err
	}

	err = qtx.DeleteWorkbookQuestions(ctx, request.WorkbookId)
	if err != nil {
		h.logger.Error("failed to delete old workbook questions", "error", err)
		return nil, err
	}
	if body.QuestionIds != nil {
		for i, qID := range *body.QuestionIds {
			err = qtx.CreateWorkbookQuestion(ctx, db.CreateWorkbookQuestionParams{
				WorkbookID: request.WorkbookId,
				QuestionID: qID,
				OrderIndex: int32(i),
			})
			if err != nil {
				h.logger.Error("failed to insert workbook question", "error", err, "question_id", qID)
				return nil, err
			}
		}
	}

	if err := tx.Commit(); err != nil {
		h.logger.Error("failed to commit transaction", "error", err)
		return nil, err
	}

	w, err := h.getWorkbookDetail(ctx, request.WorkbookId)
	if err != nil {
		h.logger.Error("failed to get updated workbook", "error", err)
		return nil, err
	}

	return adminapi.UpdateWorkbook200JSONResponse(*w), nil
}

func (h *Handler) DeleteWorkbook(ctx context.Context, request adminapi.DeleteWorkbookRequestObject) (adminapi.DeleteWorkbookResponseObject, error) {
	result, err := h.queries.DeleteWorkbook(ctx, request.WorkbookId)
	if err != nil {
		h.logger.Error("failed to delete workbook", "error", err, "workbook_id", request.WorkbookId)
		return nil, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, err
	}
	if rowsAffected == 0 {
		return adminapi.DeleteWorkbook404JSONResponse{Code: "NOT_FOUND", Message: "workbook not found"}, nil
	}

	return adminapi.DeleteWorkbook204Response{}, nil
}

// --- Images ---

func (h *Handler) CreatePresignedUrl(ctx context.Context, request adminapi.CreatePresignedUrlRequestObject) (adminapi.CreatePresignedUrlResponseObject, error) {
	body := request.Body

	if h.s3Client == nil {
		return adminapi.CreatePresignedUrl400JSONResponse{Code: "NOT_CONFIGURED", Message: "S3 is not configured"}, nil
	}

	ext := ".png"
	if body.ContentType == adminapi.Imagejpeg {
		ext = ".jpg"
	}
	objectKey := uuid.New().String() + ext

	imageID, err := h.queries.CreateImage(ctx, objectKey)
	if err != nil {
		h.logger.Error("failed to insert image", "error", err)
		return nil, err
	}

	presignClient := s3.NewPresignClient(h.s3Client)
	presignResult, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(h.s3Bucket),
		Key:         aws.String(objectKey),
		ContentType: aws.String(string(body.ContentType)),
	}, s3.WithPresignExpires(15*time.Minute))
	if err != nil {
		h.logger.Error("failed to generate presigned URL", "error", err)
		return nil, err
	}

	return adminapi.CreatePresignedUrl200JSONResponse{
		UploadUrl: presignResult.URL,
		ImageId:   imageID,
		CdnUrl:    fmt.Sprintf("%s/%s", h.imageBaseURL, objectKey),
	}, nil
}
