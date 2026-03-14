package handler

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"

	"github.com/takoikatakotako/rikako/internal/api"
)

type Handler struct {
	db           *sql.DB
	imageBaseURL string
	logger       *slog.Logger
}

func New(db *sql.DB, imageBaseURL string, logger *slog.Logger) *Handler {
	return &Handler{
		db:           db,
		imageBaseURL: imageBaseURL,
		logger:       logger,
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

// getImageURLs returns image URLs for a given question ID
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

func (h *Handler) GetQuestions(ctx context.Context, request api.GetQuestionsRequestObject) (api.GetQuestionsResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetQuestions400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	// 総件数取得
	var total int
	err = h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM questions").Scan(&total)
	if err != nil {
		h.logger.Error("failed to count questions", "error", err)
		return nil, err
	}

	// 問題一覧取得
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

	questions := []api.Question{}
	for rows.Next() {
		var id int64
		var text string
		var explanation sql.NullString

		if err := rows.Scan(&id, &text, &explanation); err != nil {
			h.logger.Error("failed to scan question", "error", err)
			return nil, err
		}

		// 選択肢取得
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

		var choices []string
		var correct int
		for choiceRows.Next() {
			var choiceText string
			var isCorrect bool
			var choiceIndex int
			if err := choiceRows.Scan(&choiceText, &isCorrect, &choiceIndex); err != nil {
				choiceRows.Close()
				h.logger.Error("failed to scan choice", "error", err)
				return nil, err
			}
			choices = append(choices, choiceText)
			if isCorrect {
				correct = choiceIndex
			}
		}
		choiceRows.Close()

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

	return api.GetQuestions200JSONResponse{
		Questions: questions,
		Total:     total,
	}, nil
}

func (h *Handler) GetQuestion(ctx context.Context, request api.GetQuestionRequestObject) (api.GetQuestionResponseObject, error) {
	var id int64
	var text string
	var explanation sql.NullString

	err := h.db.QueryRowContext(ctx, `
		SELECT q.id, qsc.text, qsc.explanation
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		WHERE q.id = $1
	`, request.QuestionId).Scan(&id, &text, &explanation)
	if err == sql.ErrNoRows {
		return api.GetQuestion404JSONResponse{Code: "NOT_FOUND", Message: "question not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to query question", "error", err, "question_id", request.QuestionId)
		return nil, err
	}

	// 選択肢取得
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
	defer choiceRows.Close()

	var choices []string
	var correct int
	for choiceRows.Next() {
		var choiceText string
		var isCorrect bool
		var choiceIndex int
		if err := choiceRows.Scan(&choiceText, &isCorrect, &choiceIndex); err != nil {
			h.logger.Error("failed to scan choice", "error", err)
			return nil, err
		}
		choices = append(choices, choiceText)
		if isCorrect {
			correct = choiceIndex
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

	imageURLs, err := h.getImageURLs(ctx, id)
	if err != nil {
		h.logger.Error("failed to get image URLs", "error", err, "question_id", id)
		return nil, err
	}
	if len(imageURLs) > 0 {
		q.Images = &imageURLs
	}

	return api.GetQuestion200JSONResponse(q), nil
}

func (h *Handler) GetWorkbooks(ctx context.Context, request api.GetWorkbooksRequestObject) (api.GetWorkbooksResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return api.GetWorkbooks400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	// 総件数取得
	var total int
	err = h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM workbooks").Scan(&total)
	if err != nil {
		h.logger.Error("failed to count workbooks", "error", err)
		return nil, err
	}

	// 問題集一覧取得
	rows, err := h.db.QueryContext(ctx, `
		SELECT w.id, w.title, w.description,
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

	workbooks := []api.Workbook{}
	for rows.Next() {
		var id int64
		var title string
		var description sql.NullString
		var questionCount int

		if err := rows.Scan(&id, &title, &description, &questionCount); err != nil {
			h.logger.Error("failed to scan workbook", "error", err)
			return nil, err
		}

		w := api.Workbook{
			Id:            id,
			Title:         title,
			QuestionCount: &questionCount,
		}
		if description.Valid {
			w.Description = &description.String
		}

		workbooks = append(workbooks, w)
	}

	return api.GetWorkbooks200JSONResponse{
		Workbooks: workbooks,
		Total:     total,
	}, nil
}

func (h *Handler) GetWorkbook(ctx context.Context, request api.GetWorkbookRequestObject) (api.GetWorkbookResponseObject, error) {
	var id int64
	var title string
	var description sql.NullString

	err := h.db.QueryRowContext(ctx, `
		SELECT id, title, description FROM workbooks WHERE id = $1
	`, request.WorkbookId).Scan(&id, &title, &description)
	if err == sql.ErrNoRows {
		return api.GetWorkbook404JSONResponse{Code: "NOT_FOUND", Message: "workbook not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to query workbook", "error", err, "workbook_id", request.WorkbookId)
		return nil, err
	}

	// 問題一覧取得
	rows, err := h.db.QueryContext(ctx, `
		SELECT q.id, qsc.text, qsc.explanation
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		JOIN workbook_questions wq ON q.id = wq.question_id
		WHERE wq.workbook_id = $1
		ORDER BY wq.order_index
	`, id)
	if err != nil {
		h.logger.Error("failed to query workbook questions", "error", err, "workbook_id", id)
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

		// 選択肢取得
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
				h.logger.Error("failed to scan choice", "error", err)
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

	w := api.WorkbookDetail{
		Id:        id,
		Title:     title,
		Questions: questions,
	}
	if description.Valid {
		w.Description = &description.String
	}

	return api.GetWorkbook200JSONResponse(w), nil
}
