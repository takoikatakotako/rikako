package admin

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	s3sdk "github.com/aws/aws-sdk-go-v2/service/s3"
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

	_, err = h.s3Client.PutObject(ctx, &s3sdk.PutObjectInput{
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
	rows, err := h.queries.ListAllCategories(ctx)
	if err != nil {
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

	return categories, nil
}

func (h *Handler) buildCategoryDetail(ctx context.Context, categoryID int64) (api.CategoryDetail, error) {
	cat, err := h.queries.GetCategoryTitle(ctx, categoryID)
	if err != nil {
		return api.CategoryDetail{}, err
	}

	wbRows, err := h.queries.ListWorkbooksByCategory(ctx, sql.NullInt64{Int64: categoryID, Valid: true})
	if err != nil {
		return api.CategoryDetail{}, err
	}

	workbooks := []api.Workbook{}
	for _, row := range wbRows {
		qc := int(row.QuestionCount)
		w := api.Workbook{
			Id:            row.ID,
			Title:         row.Title,
			QuestionCount: &qc,
			CategoryId:    &categoryID,
		}
		if row.Description.Valid {
			w.Description = &row.Description.String
		}
		workbooks = append(workbooks, w)
	}

	detail := api.CategoryDetail{
		Id:        categoryID,
		Title:     cat.Title,
		Workbooks: workbooks,
	}
	if cat.Description.Valid {
		detail.Description = &cat.Description.String
	}
	return detail, nil
}

func (h *Handler) buildWorkbooks(ctx context.Context) ([]api.Workbook, error) {
	rows, err := h.queries.ListAllWorkbooks(ctx)
	if err != nil {
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

	return workbooks, nil
}

func (h *Handler) buildWorkbookDetail(ctx context.Context, workbookID int64) (api.WorkbookDetail, error) {
	wb, err := h.queries.GetWorkbookTitle(ctx, workbookID)
	if err != nil {
		return api.WorkbookDetail{}, err
	}

	// 問題・選択肢・正解を1クエリで一括取得
	rows, err := h.queries.ListQuestionsWithChoicesByWorkbook(ctx, workbookID)
	if err != nil {
		return api.WorkbookDetail{}, err
	}

	type questionData struct {
		question api.Question
	}
	questionsMap := map[int64]*questionData{}
	var questionOrder []int64

	for _, row := range rows {
		qd, exists := questionsMap[row.ID]
		if !exists {
			q := api.Question{
				Id:   row.ID,
				Type: api.SingleChoice,
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
			qd.question.Choices = append(qd.question.Choices, row.ChoiceText.String)
			if row.IsCorrect.Valid && row.IsCorrect.Bool {
				idx := int(row.ChoiceIndex.Int32)
				qd.question.Correct = &idx
			}
		}
	}

	// 画像を一括取得
	if len(questionOrder) > 0 {
		imageRows, err := h.queries.GetImageURLsByQuestionIDs(ctx, questionOrder)
		if err != nil {
			return api.WorkbookDetail{}, err
		}

		for _, imgRow := range imageRows {
			if qd, ok := questionsMap[imgRow.QuestionID]; ok {
				url := fmt.Sprintf("%s/%s", h.imageBaseURL, imgRow.Path)
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
		Title:     wb.Title,
		Questions: questions,
	}
	if wb.Description.Valid {
		detail.Description = &wb.Description.String
	}
	if wb.CategoryID.Valid {
		cid := wb.CategoryID.Int64
		detail.CategoryId = &cid
	}
	return detail, nil
}
