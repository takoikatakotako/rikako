package admin

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/adminapi"
	"github.com/takoikatakotako/rikako/internal/api"
)

func (h *Handler) PostPublish(ctx context.Context, _ adminapi.PostPublishRequestObject) (adminapi.PostPublishResponseObject, error) {
	if h.s3Client == nil || h.contentS3Bucket == "" {
		return adminapi.PostPublish500JSONResponse{
			Code:    "NOT_CONFIGURED",
			Message: "content S3 bucket is not configured",
		}, nil
	}

	// カテゴリ一覧を生成・アップロード
	categories, err := h.buildCategories(ctx)
	if err != nil {
		h.logger.Error("failed to build categories", "error", err)
		return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to build categories"}, nil
	}

	categoriesResp := api.CategoriesResponse{
		Categories: categories,
		Total:      len(categories),
	}
	if err := h.uploadJSON(ctx, "v1/categories.json", categoriesResp); err != nil {
		h.logger.Error("failed to upload categories.json", "error", err)
		return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to upload categories.json"}, nil
	}

	// カテゴリ詳細を生成・アップロード
	for _, c := range categories {
		detail, err := h.buildCategoryDetail(ctx, c.Id)
		if err != nil {
			h.logger.Error("failed to build category detail", "error", err, "category_id", c.Id)
			return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: fmt.Sprintf("failed to build category %d", c.Id)}, nil
		}
		if err := h.uploadJSON(ctx, fmt.Sprintf("v1/categories/%d.json", c.Id), detail); err != nil {
			h.logger.Error("failed to upload category detail", "error", err, "category_id", c.Id)
			return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: fmt.Sprintf("failed to upload category %d", c.Id)}, nil
		}
	}

	// ワークブック一覧を生成・アップロード
	workbooks, err := h.buildWorkbooks(ctx)
	if err != nil {
		h.logger.Error("failed to build workbooks", "error", err)
		return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to build workbooks"}, nil
	}

	workbooksResp := api.WorkbooksResponse{
		Workbooks: workbooks,
		Total:     len(workbooks),
	}
	if err := h.uploadJSON(ctx, "v1/workbooks.json", workbooksResp); err != nil {
		h.logger.Error("failed to upload workbooks.json", "error", err)
		return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to upload workbooks.json"}, nil
	}

	// ワークブック詳細を生成・アップロード
	for _, w := range workbooks {
		detail, err := h.buildWorkbookDetail(ctx, w.Id)
		if err != nil {
			h.logger.Error("failed to build workbook detail", "error", err, "workbook_id", w.Id)
			return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: fmt.Sprintf("failed to build workbook %d", w.Id)}, nil
		}
		if err := h.uploadJSON(ctx, fmt.Sprintf("v1/workbooks/%d.json", w.Id), detail); err != nil {
			h.logger.Error("failed to upload workbook detail", "error", err, "workbook_id", w.Id)
			return adminapi.PostPublish500JSONResponse{Code: "INTERNAL_ERROR", Message: fmt.Sprintf("failed to upload workbook %d", w.Id)}, nil
		}
	}

	categoriesCount := len(categories)
	workbooksCount := len(workbooks)
	now := time.Now()

	return adminapi.PostPublish200JSONResponse{
		Message:         "published successfully",
		PublishedAt:     now,
		CategoriesCount: &categoriesCount,
		WorkbooksCount:  &workbooksCount,
	}, nil
}

func (h *Handler) uploadJSON(ctx context.Context, key string, data any) error {
	jsonBytes, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshal JSON: %w", err)
	}

	_, err = h.s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:       aws.String(h.contentS3Bucket),
		Key:          aws.String(key),
		Body:         bytes.NewReader(jsonBytes),
		ContentType:  aws.String("application/json"),
		CacheControl: aws.String("public, max-age=60"),
	})
	if err != nil {
		return fmt.Errorf("put S3 object %s: %w", key, err)
	}

	h.logger.Info("uploaded JSON", "key", key, "size", len(jsonBytes))
	return nil
}

func (h *Handler) buildCategories(ctx context.Context) ([]api.Category, error) {
	rows, err := h.db.QueryContext(ctx, `
		SELECT c.id, c.title, c.description,
			(SELECT COUNT(*) FROM workbooks w WHERE w.category_id = c.id) as workbook_count
		FROM categories c
		ORDER BY c.id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var categories []api.Category
	for rows.Next() {
		var id int64
		var title string
		var description sql.NullString
		var workbookCount int

		if err := rows.Scan(&id, &title, &description, &workbookCount); err != nil {
			return nil, err
		}

		c := api.Category{
			Id:            id,
			Title:         title,
			WorkbookCount: &workbookCount,
		}
		if description.Valid {
			c.Description = &description.String
		}
		categories = append(categories, c)
	}

	if categories == nil {
		categories = []api.Category{}
	}
	return categories, nil
}

func (h *Handler) buildCategoryDetail(ctx context.Context, categoryID int64) (api.CategoryDetail, error) {
	var title string
	var description sql.NullString

	err := h.db.QueryRowContext(ctx, `
		SELECT title, description FROM categories WHERE id = $1
	`, categoryID).Scan(&title, &description)
	if err != nil {
		return api.CategoryDetail{}, err
	}

	rows, err := h.db.QueryContext(ctx, `
		SELECT w.id, w.title, w.description,
			(SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
		FROM workbooks w
		WHERE w.category_id = $1
		ORDER BY w.id
	`, categoryID)
	if err != nil {
		return api.CategoryDetail{}, err
	}
	defer rows.Close()

	var workbooks []api.Workbook
	for rows.Next() {
		var wid int64
		var wtitle string
		var wdesc sql.NullString
		var questionCount int

		if err := rows.Scan(&wid, &wtitle, &wdesc, &questionCount); err != nil {
			return api.CategoryDetail{}, err
		}

		w := api.Workbook{
			Id:            wid,
			Title:         wtitle,
			QuestionCount: &questionCount,
			CategoryId:    &categoryID,
		}
		if wdesc.Valid {
			w.Description = &wdesc.String
		}
		workbooks = append(workbooks, w)
	}

	if workbooks == nil {
		workbooks = []api.Workbook{}
	}

	detail := api.CategoryDetail{
		Id:        categoryID,
		Title:     title,
		Workbooks: workbooks,
	}
	if description.Valid {
		detail.Description = &description.String
	}
	return detail, nil
}

func (h *Handler) buildWorkbooks(ctx context.Context) ([]api.Workbook, error) {
	rows, err := h.db.QueryContext(ctx, `
		SELECT w.id, w.title, w.description, w.category_id,
			(SELECT COUNT(*) FROM workbook_questions wq WHERE wq.workbook_id = w.id) as question_count
		FROM workbooks w
		ORDER BY w.id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var workbooks []api.Workbook
	for rows.Next() {
		var id int64
		var title string
		var description sql.NullString
		var categoryID sql.NullInt64
		var questionCount int

		if err := rows.Scan(&id, &title, &description, &categoryID, &questionCount); err != nil {
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
		if categoryID.Valid {
			cid := categoryID.Int64
			w.CategoryId = &cid
		}
		workbooks = append(workbooks, w)
	}

	if workbooks == nil {
		workbooks = []api.Workbook{}
	}
	return workbooks, nil
}

func (h *Handler) buildWorkbookDetail(ctx context.Context, workbookID int64) (api.WorkbookDetail, error) {
	var title string
	var description sql.NullString
	var categoryID sql.NullInt64

	err := h.db.QueryRowContext(ctx, `
		SELECT title, description, category_id FROM workbooks WHERE id = $1
	`, workbookID).Scan(&title, &description, &categoryID)
	if err != nil {
		return api.WorkbookDetail{}, err
	}

	// 問題・選択肢・正解を1クエリで一括取得
	rows, err := h.db.QueryContext(ctx, `
		SELECT q.id, qsc.text, qsc.explanation,
			c.text AS choice_text, c.is_correct, c.choice_index
		FROM questions q
		JOIN questions_single_choice qsc ON q.id = qsc.question_id
		JOIN workbook_questions wq ON q.id = wq.question_id
		LEFT JOIN questions_single_choice_choices c
			ON c.single_choice_id = qsc.id
		WHERE wq.workbook_id = $1
		ORDER BY wq.order_index, c.choice_index
	`, workbookID)
	if err != nil {
		return api.WorkbookDetail{}, err
	}
	defer rows.Close()

	type questionData struct {
		question api.Question
		order    int
	}
	questionsMap := map[int64]*questionData{}
	var questionOrder []int64
	orderIdx := 0

	for rows.Next() {
		var qid int64
		var text string
		var explanation sql.NullString
		var choiceText sql.NullString
		var isCorrect sql.NullBool
		var choiceIndex sql.NullInt64

		if err := rows.Scan(&qid, &text, &explanation, &choiceText, &isCorrect, &choiceIndex); err != nil {
			return api.WorkbookDetail{}, err
		}

		qd, exists := questionsMap[qid]
		if !exists {
			q := api.Question{
				Id:   qid,
				Type: api.SingleChoice,
				Text: text,
			}
			if explanation.Valid {
				q.Explanation = &explanation.String
			}
			qd = &questionData{question: q, order: orderIdx}
			questionsMap[qid] = qd
			questionOrder = append(questionOrder, qid)
			orderIdx++
		}

		if choiceText.Valid {
			qd.question.Choices = append(qd.question.Choices, choiceText.String)
			if isCorrect.Valid && isCorrect.Bool {
				idx := int(choiceIndex.Int64)
				qd.question.Correct = &idx
			}
		}
	}

	// 画像を一括取得
	if len(questionOrder) > 0 {
		imageRows, err := h.db.QueryContext(ctx, `
			SELECT qi.question_id, i.path
			FROM question_images qi
			JOIN images i ON i.id = qi.image_id
			WHERE qi.question_id = ANY($1)
			ORDER BY qi.question_id, qi.order_index
		`, pq.Array(questionOrder))
		if err != nil {
			return api.WorkbookDetail{}, err
		}
		defer imageRows.Close()

		for imageRows.Next() {
			var qid int64
			var path string
			if err := imageRows.Scan(&qid, &path); err != nil {
				return api.WorkbookDetail{}, err
			}
			if qd, ok := questionsMap[qid]; ok {
				url := fmt.Sprintf("%s/%s", h.imageBaseURL, path)
				if qd.question.Images == nil {
					urls := []string{url}
					qd.question.Images = &urls
				} else {
					*qd.question.Images = append(*qd.question.Images, url)
				}
			}
		}
	}

	// 順序通りに組み立て
	questions := make([]api.Question, 0, len(questionOrder))
	for _, qid := range questionOrder {
		questions = append(questions, questionsMap[qid].question)
	}

	detail := api.WorkbookDetail{
		Id:        workbookID,
		Title:     title,
		Questions: questions,
	}
	if description.Valid {
		detail.Description = &description.String
	}
	if categoryID.Valid {
		cid := categoryID.Int64
		detail.CategoryId = &cid
	}
	return detail, nil
}
