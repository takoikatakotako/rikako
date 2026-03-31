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
)

type Handler struct {
	db              *sql.DB
	imageBaseURL    string
	s3Client        *s3.Client
	s3Bucket        string
	contentS3Bucket string
	logger          *slog.Logger
}

func New(db *sql.DB, imageBaseURL string, s3Client *s3.Client, s3Bucket string, contentS3Bucket string, logger *slog.Logger) *Handler {
	return &Handler{
		db:              db,
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
	rows, err := h.db.QueryContext(ctx, `
		SELECT i.path
		FROM images i
		JOIN question_images qi ON i.id = qi.image_id
		WHERE qi.question_id = $1
		ORDER BY qi.order_index
	`, questionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var urls []string
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			return nil, err
		}
		urls = append(urls, fmt.Sprintf("%s/%s", h.imageBaseURL, path))
	}
	return urls, nil
}

// getQuestionByID fetches a full question with choices and images.
func (h *Handler) getQuestionByID(ctx context.Context, questionID int64) (*adminapi.Question, error) {
	var id int64
	var text string
	var explanation sql.NullString

	err := h.db.QueryRowContext(ctx, `
		SELECT q.id, qsc.text, qsc.explanation
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		WHERE q.id = $1
	`, questionID).Scan(&id, &text, &explanation)
	if err != nil {
		return nil, err
	}

	choiceRows, err := h.db.QueryContext(ctx, `
		SELECT text, is_correct, choice_index
		FROM questions_single_choice_choices
		WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
		ORDER BY choice_index
	`, id)
	if err != nil {
		return nil, err
	}
	defer choiceRows.Close()

	var choices []adminapi.Choice
	for choiceRows.Next() {
		var choiceText string
		var isCorrect bool
		var choiceIndex int
		if err := choiceRows.Scan(&choiceText, &isCorrect, &choiceIndex); err != nil {
			return nil, err
		}
		choices = append(choices, adminapi.Choice{Text: choiceText, IsCorrect: isCorrect})
	}

	q := &adminapi.Question{
		Id:      id,
		Type:    adminapi.QuestionTypeSingleChoice,
		Text:    text,
		Choices: choices,
	}
	if explanation.Valid {
		q.Explanation = &explanation.String
	}

	imageURLs, err := h.getImageURLs(ctx, id)
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

	var total int
	if err := h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM categories").Scan(&total); err != nil {
		h.logger.Error("failed to count categories", "error", err)
		return nil, err
	}

	rows, err := h.db.QueryContext(ctx, `
		SELECT c.id, c.title, c.description,
			(SELECT COUNT(*) FROM workbooks w WHERE w.category_id = c.id) as workbook_count
		FROM categories c
		ORDER BY c.id
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		h.logger.Error("failed to query categories", "error", err)
		return nil, err
	}
	defer rows.Close()

	categories := []adminapi.Category{}
	for rows.Next() {
		var id int64
		var title string
		var description sql.NullString
		var workbookCount int
		if err := rows.Scan(&id, &title, &description, &workbookCount); err != nil {
			h.logger.Error("failed to scan category", "error", err)
			return nil, err
		}
		c := adminapi.Category{
			Id:            id,
			Title:         title,
			WorkbookCount: &workbookCount,
		}
		if description.Valid {
			c.Description = &description.String
		}
		categories = append(categories, c)
	}

	return adminapi.GetCategories200JSONResponse{Categories: categories, Total: total}, nil
}

// getCategoryDetail fetches a category with its workbooks.
func (h *Handler) getCategoryDetail(ctx context.Context, categoryID int64) (*adminapi.CategoryDetail, error) {
	var id int64
	var title string
	var description sql.NullString

	err := h.db.QueryRowContext(ctx, `SELECT id, title, description FROM categories WHERE id = $1`, categoryID).Scan(&id, &title, &description)
	if err != nil {
		return nil, err
	}

	rows, err := h.db.QueryContext(ctx, `
		SELECT w.id, w.title, w.description,
			(SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
		FROM workbooks w
		WHERE w.category_id = $1
		ORDER BY w.id
	`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	workbooks := []adminapi.Workbook{}
	for rows.Next() {
		var wid int64
		var wtitle string
		var wdesc sql.NullString
		var questionCount int
		if err := rows.Scan(&wid, &wtitle, &wdesc, &questionCount); err != nil {
			return nil, err
		}
		w := adminapi.Workbook{
			Id:            wid,
			Title:         wtitle,
			QuestionCount: &questionCount,
			CategoryId:    &id,
		}
		if wdesc.Valid {
			w.Description = &wdesc.String
		}
		workbooks = append(workbooks, w)
	}

	c := &adminapi.CategoryDetail{
		Id:        id,
		Title:     title,
		Workbooks: workbooks,
	}
	if description.Valid {
		c.Description = &description.String
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

	var categoryID int64
	var descArg any
	if body.Description != nil {
		descArg = *body.Description
	}
	err := h.db.QueryRowContext(ctx, `
		INSERT INTO categories (title, description) VALUES ($1, $2) RETURNING id
	`, body.Title, descArg).Scan(&categoryID)
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

	var exists bool
	err := h.db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM categories WHERE id = $1)`, request.CategoryId).Scan(&exists)
	if err != nil {
		h.logger.Error("failed to check category existence", "error", err)
		return nil, err
	}
	if !exists {
		return adminapi.UpdateCategory404JSONResponse{Code: "NOT_FOUND", Message: "category not found"}, nil
	}

	var descArg any
	if body.Description != nil {
		descArg = *body.Description
	}
	_, err = h.db.ExecContext(ctx, `
		UPDATE categories SET title = $1, description = $2, updated_at = $3 WHERE id = $4
	`, body.Title, descArg, time.Now(), request.CategoryId)
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
	result, err := h.db.ExecContext(ctx, `DELETE FROM categories WHERE id = $1`, request.CategoryId)
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

	var total int
	if err := h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM questions").Scan(&total); err != nil {
		h.logger.Error("failed to count questions", "error", err)
		return nil, err
	}

	rows, err := h.db.QueryContext(ctx, `
		SELECT q.id, qsc.text, qsc.explanation
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		ORDER BY q.id
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		h.logger.Error("failed to query questions", "error", err)
		return nil, err
	}
	defer rows.Close()

	questions := []adminapi.Question{}
	for rows.Next() {
		var id int64
		var text string
		var explanation sql.NullString
		if err := rows.Scan(&id, &text, &explanation); err != nil {
			h.logger.Error("failed to scan question", "error", err)
			return nil, err
		}

		choiceRows, err := h.db.QueryContext(ctx, `
			SELECT text, is_correct, choice_index
			FROM questions_single_choice_choices
			WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
			ORDER BY choice_index
		`, id)
		if err != nil {
			h.logger.Error("failed to query choices", "error", err, "question_id", id)
			return nil, err
		}

		var choices []adminapi.Choice
		for choiceRows.Next() {
			var choiceText string
			var isCorrect bool
			var choiceIndex int
			if err := choiceRows.Scan(&choiceText, &isCorrect, &choiceIndex); err != nil {
				choiceRows.Close()
				h.logger.Error("failed to scan choice", "error", err)
				return nil, err
			}
			choices = append(choices, adminapi.Choice{Text: choiceText, IsCorrect: isCorrect})
		}
		choiceRows.Close()

		q := adminapi.Question{
			Id:      id,
			Type:    adminapi.QuestionTypeSingleChoice,
			Text:    text,
			Choices: choices,
		}
		if explanation.Valid {
			q.Explanation = &explanation.String
		}

		imageURLs, err := h.getImageURLs(ctx, id)
		if err != nil {
			h.logger.Error("failed to get image URLs", "error", err, "question_id", id)
			return nil, err
		}
		if len(imageURLs) > 0 {
			q.Images = &imageURLs
		}

		questions = append(questions, q)
	}

	return adminapi.GetQuestions200JSONResponse{Questions: questions, Total: total}, nil
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

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	var questionID int64
	err = tx.QueryRowContext(ctx, `INSERT INTO questions (type) VALUES ($1) RETURNING id`, string(body.Type)).Scan(&questionID)
	if err != nil {
		h.logger.Error("failed to insert question", "error", err)
		return nil, err
	}

	var singleChoiceID int64
	var explanationArg any
	if body.Explanation != nil {
		explanationArg = *body.Explanation
	}
	err = tx.QueryRowContext(ctx, `
		INSERT INTO questions_single_choice (question_id, text, explanation)
		VALUES ($1, $2, $3) RETURNING id
	`, questionID, body.Text, explanationArg).Scan(&singleChoiceID)
	if err != nil {
		h.logger.Error("failed to insert single choice", "error", err)
		return nil, err
	}

	for i, c := range body.Choices {
		_, err = tx.ExecContext(ctx, `
			INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct)
			VALUES ($1, $2, $3, $4)
		`, singleChoiceID, i, c.Text, c.IsCorrect)
		if err != nil {
			h.logger.Error("failed to insert choice", "error", err)
			return nil, err
		}
	}

	if body.ImageIds != nil {
		for i, imageID := range *body.ImageIds {
			_, err = tx.ExecContext(ctx, `
				INSERT INTO question_images (question_id, image_id, order_index)
				VALUES ($1, $2, $3)
			`, questionID, imageID, i)
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

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	// Check existence
	var exists bool
	err = tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM questions WHERE id = $1)`, request.QuestionId).Scan(&exists)
	if err != nil {
		h.logger.Error("failed to check question existence", "error", err)
		return nil, err
	}
	if !exists {
		return adminapi.UpdateQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}

	// Update single choice text/explanation
	var explanationArg any
	if body.Explanation != nil {
		explanationArg = *body.Explanation
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE questions_single_choice SET text = $1, explanation = $2, updated_at = $3
		WHERE question_id = $4
	`, body.Text, explanationArg, time.Now(), request.QuestionId)
	if err != nil {
		h.logger.Error("failed to update single choice", "error", err)
		return nil, err
	}

	// Delete old choices and re-insert
	_, err = tx.ExecContext(ctx, `
		DELETE FROM questions_single_choice_choices
		WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
	`, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to delete old choices", "error", err)
		return nil, err
	}

	var singleChoiceID int64
	err = tx.QueryRowContext(ctx, `SELECT id FROM questions_single_choice WHERE question_id = $1`, request.QuestionId).Scan(&singleChoiceID)
	if err != nil {
		h.logger.Error("failed to get single choice id", "error", err)
		return nil, err
	}

	for i, c := range body.Choices {
		_, err = tx.ExecContext(ctx, `
			INSERT INTO questions_single_choice_choices (single_choice_id, choice_index, text, is_correct)
			VALUES ($1, $2, $3, $4)
		`, singleChoiceID, i, c.Text, c.IsCorrect)
		if err != nil {
			h.logger.Error("failed to insert choice", "error", err)
			return nil, err
		}
	}

	// Update image associations
	_, err = tx.ExecContext(ctx, `DELETE FROM question_images WHERE question_id = $1`, request.QuestionId)
	if err != nil {
		h.logger.Error("failed to delete old question images", "error", err)
		return nil, err
	}
	if body.ImageIds != nil {
		for i, imageID := range *body.ImageIds {
			_, err = tx.ExecContext(ctx, `
				INSERT INTO question_images (question_id, image_id, order_index)
				VALUES ($1, $2, $3)
			`, request.QuestionId, imageID, i)
			if err != nil {
				h.logger.Error("failed to insert question image", "error", err, "image_id", imageID)
				return nil, err
			}
		}
	}

	// Update timestamp
	_, err = tx.ExecContext(ctx, `UPDATE questions SET updated_at = $1 WHERE id = $2`, time.Now(), request.QuestionId)
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
	result, err := h.db.ExecContext(ctx, `DELETE FROM questions WHERE id = $1`, request.QuestionId)
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

	var total int
	if err := h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM workbooks").Scan(&total); err != nil {
		h.logger.Error("failed to count workbooks", "error", err)
		return nil, err
	}

	rows, err := h.db.QueryContext(ctx, `
		SELECT w.id, w.title, w.description, w.category_id,
			(SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
		FROM workbooks w
		ORDER BY w.id
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		h.logger.Error("failed to query workbooks", "error", err)
		return nil, err
	}
	defer rows.Close()

	workbooks := []adminapi.Workbook{}
	for rows.Next() {
		var id int64
		var title string
		var description sql.NullString
		var categoryID sql.NullInt64
		var questionCount int
		if err := rows.Scan(&id, &title, &description, &categoryID, &questionCount); err != nil {
			h.logger.Error("failed to scan workbook", "error", err)
			return nil, err
		}
		w := adminapi.Workbook{
			Id:            id,
			Title:         title,
			QuestionCount: &questionCount,
		}
		if description.Valid {
			w.Description = &description.String
		}
		if categoryID.Valid {
			cid := categoryID.Int64
			w.CategoryId = &cid
		}
		workbooks = append(workbooks, w)
	}

	return adminapi.GetWorkbooks200JSONResponse{Workbooks: workbooks, Total: total}, nil
}

// getWorkbookDetail fetches a workbook with its questions.
func (h *Handler) getWorkbookDetail(ctx context.Context, workbookID int64) (*adminapi.WorkbookDetail, error) {
	var id int64
	var title string
	var description sql.NullString
	var categoryID sql.NullInt64

	err := h.db.QueryRowContext(ctx, `SELECT id, title, description, category_id FROM workbooks WHERE id = $1`, workbookID).Scan(&id, &title, &description, &categoryID)
	if err != nil {
		return nil, err
	}

	rows, err := h.db.QueryContext(ctx, `
		SELECT q.id, qsc.text, qsc.explanation
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		JOIN workbook_questions wq ON q.id = wq.question_id
		WHERE wq.workbook_id = $1
		ORDER BY wq.order_index
	`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	questions := []adminapi.Question{}
	for rows.Next() {
		var qid int64
		var text string
		var explanation sql.NullString
		if err := rows.Scan(&qid, &text, &explanation); err != nil {
			return nil, err
		}

		choiceRows, err := h.db.QueryContext(ctx, `
			SELECT text, is_correct, choice_index
			FROM questions_single_choice_choices
			WHERE single_choice_id = (SELECT id FROM questions_single_choice WHERE question_id = $1)
			ORDER BY choice_index
		`, qid)
		if err != nil {
			return nil, err
		}

		var choices []adminapi.Choice
		for choiceRows.Next() {
			var choiceText string
			var isCorrect bool
			var choiceIndex int
			if err := choiceRows.Scan(&choiceText, &isCorrect, &choiceIndex); err != nil {
				choiceRows.Close()
				return nil, err
			}
			choices = append(choices, adminapi.Choice{Text: choiceText, IsCorrect: isCorrect})
		}
		choiceRows.Close()

		q := adminapi.Question{
			Id:      qid,
			Type:    adminapi.QuestionTypeSingleChoice,
			Text:    text,
			Choices: choices,
		}
		if explanation.Valid {
			q.Explanation = &explanation.String
		}

		imageURLs, err := h.getImageURLs(ctx, qid)
		if err != nil {
			return nil, err
		}
		if len(imageURLs) > 0 {
			q.Images = &imageURLs
		}

		questions = append(questions, q)
	}

	w := &adminapi.WorkbookDetail{
		Id:        id,
		Title:     title,
		Questions: questions,
	}
	if description.Valid {
		w.Description = &description.String
	}
	if categoryID.Valid {
		cid := categoryID.Int64
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

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	var workbookID int64
	var descArg any
	if body.Description != nil {
		descArg = *body.Description
	}
	var categoryArg any
	if body.CategoryId != nil {
		categoryArg = *body.CategoryId
	}
	err = tx.QueryRowContext(ctx, `
		INSERT INTO workbooks (title, description, category_id) VALUES ($1, $2, $3) RETURNING id
	`, body.Title, descArg, categoryArg).Scan(&workbookID)
	if err != nil {
		h.logger.Error("failed to insert workbook", "error", err)
		return nil, err
	}

	if body.QuestionIds != nil {
		for i, qID := range *body.QuestionIds {
			_, err = tx.ExecContext(ctx, `
				INSERT INTO workbook_questions (workbook_id, question_id, order_index)
				VALUES ($1, $2, $3)
			`, workbookID, qID, i)
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

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin transaction", "error", err)
		return nil, err
	}
	defer tx.Rollback()

	var exists bool
	err = tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM workbooks WHERE id = $1)`, request.WorkbookId).Scan(&exists)
	if err != nil {
		h.logger.Error("failed to check workbook existence", "error", err)
		return nil, err
	}
	if !exists {
		return adminapi.UpdateWorkbook404JSONResponse{Code: "NOT_FOUND", Message: "workbook not found"}, nil
	}

	var descArg any
	if body.Description != nil {
		descArg = *body.Description
	}
	var categoryArg any
	if body.CategoryId != nil {
		categoryArg = *body.CategoryId
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE workbooks SET title = $1, description = $2, category_id = $3, updated_at = $4 WHERE id = $5
	`, body.Title, descArg, categoryArg, time.Now(), request.WorkbookId)
	if err != nil {
		h.logger.Error("failed to update workbook", "error", err)
		return nil, err
	}

	// Replace question associations
	_, err = tx.ExecContext(ctx, `DELETE FROM workbook_questions WHERE workbook_id = $1`, request.WorkbookId)
	if err != nil {
		h.logger.Error("failed to delete old workbook questions", "error", err)
		return nil, err
	}
	if body.QuestionIds != nil {
		for i, qID := range *body.QuestionIds {
			_, err = tx.ExecContext(ctx, `
				INSERT INTO workbook_questions (workbook_id, question_id, order_index)
				VALUES ($1, $2, $3)
			`, request.WorkbookId, qID, i)
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
	result, err := h.db.ExecContext(ctx, `DELETE FROM workbooks WHERE id = $1`, request.WorkbookId)
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

	// Generate UUID-based path
	ext := ".png"
	if body.ContentType == adminapi.Imagejpeg {
		ext = ".jpg"
	}
	objectKey := uuid.New().String() + ext

	// Insert image record
	var imageID int64
	err := h.db.QueryRowContext(ctx, `INSERT INTO images (path) VALUES ($1) RETURNING id`, objectKey).Scan(&imageID)
	if err != nil {
		h.logger.Error("failed to insert image", "error", err)
		return nil, err
	}

	// Generate presigned URL
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
