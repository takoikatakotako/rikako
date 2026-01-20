package handler

import (
	"context"
	"database/sql"
	"os"

	"github.com/google/uuid"
	"github.com/takoikatakotako/rikako/internal/api"
)

type Handler struct {
	db *sql.DB
}

func New(db *sql.DB) *Handler {
	return &Handler{db: db}
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

func (h *Handler) GetImage(ctx context.Context, request api.GetImageRequestObject) (api.GetImageResponseObject, error) {
	// 画像パスをDBから取得
	var path string
	err := h.db.QueryRowContext(ctx, "SELECT path FROM images WHERE id = $1", request.ImageId).Scan(&path)
	if err == sql.ErrNoRows {
		return api.GetImage404JSONResponse{Message: "image not found"}, nil
	}
	if err != nil {
		return nil, err
	}

	// 画像ファイルを開く
	file, err := os.Open("data/images/" + path)
	if err != nil {
		return api.GetImage404JSONResponse{Message: "image file not found"}, nil
	}

	stat, _ := file.Stat()
	return api.GetImage200ImagepngResponse{
		Body:          file,
		ContentLength: stat.Size(),
	}, nil
}

func (h *Handler) GetQuestions(ctx context.Context, request api.GetQuestionsRequestObject) (api.GetQuestionsResponseObject, error) {
	limit := 20
	offset := 0
	if request.Params.Limit != nil {
		limit = *request.Params.Limit
	}
	if request.Params.Offset != nil {
		offset = *request.Params.Offset
	}

	// 総件数取得
	var total int
	err := h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM questions").Scan(&total)
	if err != nil {
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
		return nil, err
	}
	defer rows.Close()

	questions := []api.Question{}
	for rows.Next() {
		var id int64
		var text string
		var explanation sql.NullString

		if err := rows.Scan(&id, &text, &explanation); err != nil {
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
			Id:      uuid.MustParse(uuidFromInt(id)),
			Type:    api.SingleChoice,
			Text:    text,
			Choices: choices,
			Correct: &correct,
		}
		if explanation.Valid {
			q.Explanation = &explanation.String
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
		return api.GetQuestion404JSONResponse{Message: "question not found"}, nil
	}
	if err != nil {
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
			return nil, err
		}
		choices = append(choices, choiceText)
		if isCorrect {
			correct = choiceIndex
		}
	}

	q := api.Question{
		Id:      request.QuestionId,
		Type:    api.SingleChoice,
		Text:    text,
		Choices: choices,
		Correct: &correct,
	}
	if explanation.Valid {
		q.Explanation = &explanation.String
	}

	return api.GetQuestion200JSONResponse(q), nil
}

func (h *Handler) GetWorkbooks(ctx context.Context, request api.GetWorkbooksRequestObject) (api.GetWorkbooksResponseObject, error) {
	limit := 20
	offset := 0
	if request.Params.Limit != nil {
		limit = *request.Params.Limit
	}
	if request.Params.Offset != nil {
		offset = *request.Params.Offset
	}

	// 総件数取得
	var total int
	err := h.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM workbooks").Scan(&total)
	if err != nil {
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
			return nil, err
		}

		w := api.Workbook{
			Id:            uuid.MustParse(uuidFromInt(id)),
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
		return api.GetWorkbook404JSONResponse{Message: "workbook not found"}, nil
	}
	if err != nil {
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
		return nil, err
	}
	defer rows.Close()

	questions := []api.Question{}
	for rows.Next() {
		var qid int64
		var text string
		var explanation sql.NullString

		if err := rows.Scan(&qid, &text, &explanation); err != nil {
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
			Id:      uuid.MustParse(uuidFromInt(qid)),
			Type:    api.SingleChoice,
			Text:    text,
			Choices: choices,
			Correct: &correct,
		}
		if explanation.Valid {
			q.Explanation = &explanation.String
		}

		questions = append(questions, q)
	}

	w := api.WorkbookDetail{
		Id:        request.WorkbookId,
		Title:     title,
		Questions: questions,
	}
	if description.Valid {
		w.Description = &description.String
	}

	return api.GetWorkbook200JSONResponse(w), nil
}

// TODO: DBのIDがBIGINTなので、UUIDとの変換が必要
// 本来はDBにUUIDを格納するか、別途マッピングテーブルを用意すべき
func uuidFromInt(id int64) string {
	return uuid.NewSHA1(uuid.NameSpaceOID, []byte(string(rune(id)))).String()
}
