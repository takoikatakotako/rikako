package admin

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/takoikatakotako/rikako/internal/adminapi"
	"github.com/takoikatakotako/rikako/internal/api"
)

func TestPostPublish_NoS3(t *testing.T) {
	h := newTestHandler()
	resp, err := h.PostPublish(context.Background(), adminapi.PostPublishRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	errResp, ok := resp.(adminapi.PostPublish500JSONResponse)
	if !ok {
		t.Fatalf("expected PostPublish500JSONResponse, got %T", resp)
	}
	if errResp.Code != "NOT_CONFIGURED" {
		t.Errorf("expected code NOT_CONFIGURED, got %s", errResp.Code)
	}
}

func TestBuildCategories(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	categories, err := h.buildCategories(ctx)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify JSON serialization matches public API format
	data, err := json.Marshal(api.CategoriesResponse{
		Categories: categories,
		Total:      len(categories),
	})
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if _, ok := result["categories"]; !ok {
		t.Error("expected 'categories' field in JSON")
	}
	if _, ok := result["total"]; !ok {
		t.Error("expected 'total' field in JSON")
	}
}

func TestBuildWorkbooks(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	workbooks, err := h.buildWorkbooks(ctx)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify JSON serialization matches public API format
	data, err := json.Marshal(api.WorkbooksResponse{
		Workbooks: workbooks,
		Total:     len(workbooks),
	})
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if _, ok := result["workbooks"]; !ok {
		t.Error("expected 'workbooks' field in JSON")
	}
	if _, ok := result["total"]; !ok {
		t.Error("expected 'total' field in JSON")
	}
}

func TestBuildWorkbookDetail_JSONFormat(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	// First create test data
	catReq := adminapi.CreateCategoryRequestObject{
		Body: &adminapi.CreateCategoryRequest{Title: "Test Category for Publish"},
	}
	catResp, err := h.CreateCategory(ctx, catReq)
	if err != nil {
		t.Fatalf("failed to create category: %v", err)
	}
	cat := catResp.(adminapi.CreateCategory201JSONResponse)
	categoryID := cat.Id

	qReq := adminapi.CreateQuestionRequestObject{
		Body: &adminapi.CreateQuestionRequest{
			Type: adminapi.CreateQuestionRequestTypeSingleChoice,
			Text: "Publish test question",
			Choices: []adminapi.Choice{
				{Text: "A", IsCorrect: true},
				{Text: "B", IsCorrect: false},
			},
		},
	}
	qResp, err := h.CreateQuestion(ctx, qReq)
	if err != nil {
		t.Fatalf("failed to create question: %v", err)
	}
	q := qResp.(adminapi.CreateQuestion201JSONResponse)

	wReq := adminapi.CreateWorkbookRequestObject{
		Body: &adminapi.CreateWorkbookRequest{
			Title:       "Publish Test Workbook",
			CategoryId:  &categoryID,
			QuestionIds: &[]int64{q.Id},
		},
	}
	wResp, err := h.CreateWorkbook(ctx, wReq)
	if err != nil {
		t.Fatalf("failed to create workbook: %v", err)
	}
	wb := wResp.(adminapi.CreateWorkbook201JSONResponse)

	// Build workbook detail
	detail, err := h.buildWorkbookDetail(ctx, wb.Id)
	if err != nil {
		t.Fatalf("failed to build workbook detail: %v", err)
	}

	// Verify JSON matches iOS Models.swift expected format
	data, err := json.Marshal(detail)
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	// Check required fields
	for _, field := range []string{"id", "title", "questions", "categoryId"} {
		if _, ok := result[field]; !ok {
			t.Errorf("expected '%s' field in WorkbookDetail JSON", field)
		}
	}

	// Check question format (public API: choices as []string, correct as int)
	questions, ok := result["questions"].([]interface{})
	if !ok || len(questions) == 0 {
		t.Fatal("expected non-empty questions array")
	}

	question := questions[0].(map[string]interface{})
	if _, ok := question["choices"]; !ok {
		t.Error("expected 'choices' in question")
	}
	// choices should be []string, not []Choice
	choices, ok := question["choices"].([]interface{})
	if !ok {
		t.Fatal("expected choices to be an array")
	}
	if _, ok := choices[0].(string); !ok {
		t.Error("expected choices to be strings (public API format), not objects (admin API format)")
	}
	if _, ok := question["correct"]; !ok {
		t.Error("expected 'correct' field in question")
	}

	// Cleanup
	h.DeleteWorkbook(ctx, adminapi.DeleteWorkbookRequestObject{WorkbookId: wb.Id})
	h.DeleteQuestion(ctx, adminapi.DeleteQuestionRequestObject{QuestionId: q.Id})
	h.DeleteCategory(ctx, adminapi.DeleteCategoryRequestObject{CategoryId: categoryID})
}
