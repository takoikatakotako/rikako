package handler

import (
	"context"
	"database/sql"
	"log/slog"
	"os"
	"testing"

	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/identity"
)

var testDB *sql.DB
var testLogger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))

func TestMain(m *testing.M) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://rikako:password@localhost:5432/rikako?sslmode=disable"
	}

	var err error
	testDB, err = sql.Open("postgres", dsn)
	if err != nil {
		panic(err)
	}
	defer testDB.Close()

	if err := testDB.Ping(); err != nil {
		panic(err)
	}

	os.Exit(m.Run())
}

func TestRoot(t *testing.T) {
	h := New(testDB, "https://example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})
	resp, err := h.Root(context.Background(), api.RootRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	res, ok := resp.(api.Root200JSONResponse)
	if !ok {
		t.Fatalf("expected Root200JSONResponse, got %T", resp)
	}
	if res.Message != "running" {
		t.Errorf("expected message 'running', got '%s'", res.Message)
	}
}

func TestHealthCheck(t *testing.T) {
	h := New(testDB, "https://example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})
	resp, err := h.HealthCheck(context.Background(), api.HealthCheckRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	res, ok := resp.(api.HealthCheck200JSONResponse)
	if !ok {
		t.Fatalf("expected HealthCheck200JSONResponse, got %T", resp)
	}
	if res.Status != "ok" {
		t.Errorf("expected status 'ok', got '%s'", res.Status)
	}
}

func TestGetQuestions(t *testing.T) {
	h := New(testDB, "https://cdn.example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})

	t.Run("default pagination", func(t *testing.T) {
		resp, err := h.GetQuestions(context.Background(), api.GetQuestionsRequestObject{})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res, ok := resp.(api.GetQuestions200JSONResponse)
		if !ok {
			t.Fatalf("expected GetQuestions200JSONResponse, got %T", resp)
		}

		if res.Total == 0 {
			t.Fatal("expected total > 0")
		}
		if len(res.Questions) == 0 {
			t.Fatal("expected questions to be non-empty")
		}
		if len(res.Questions) > 20 {
			t.Errorf("default limit should be 20, got %d", len(res.Questions))
		}

		q := res.Questions[0]
		if q.Id == 0 {
			t.Error("expected question ID to be non-zero")
		}
		if q.Text == "" {
			t.Error("expected question text to be non-empty")
		}
		if len(q.Choices) == 0 {
			t.Error("expected choices to be non-empty")
		}
		if q.Type != api.SingleChoice {
			t.Errorf("expected type 'single_choice', got '%s'", q.Type)
		}
	})

	t.Run("custom pagination", func(t *testing.T) {
		limit := 5
		offset := 2
		resp, err := h.GetQuestions(context.Background(), api.GetQuestionsRequestObject{
			Params: api.GetQuestionsParams{
				Limit:  &limit,
				Offset: &offset,
			},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res := resp.(api.GetQuestions200JSONResponse)
		if len(res.Questions) != 5 {
			t.Errorf("expected 5 questions, got %d", len(res.Questions))
		}
	})

	t.Run("invalid limit zero", func(t *testing.T) {
		limit := 0
		resp, err := h.GetQuestions(context.Background(), api.GetQuestionsRequestObject{
			Params: api.GetQuestionsParams{Limit: &limit},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		res, ok := resp.(api.GetQuestions400JSONResponse)
		if !ok {
			t.Fatalf("expected GetQuestions400JSONResponse, got %T", resp)
		}
		if res.Code != "INVALID_PARAMETER" {
			t.Errorf("expected code 'INVALID_PARAMETER', got '%s'", res.Code)
		}
	})

	t.Run("invalid limit over 100", func(t *testing.T) {
		limit := 101
		resp, err := h.GetQuestions(context.Background(), api.GetQuestionsRequestObject{
			Params: api.GetQuestionsParams{Limit: &limit},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		_, ok := resp.(api.GetQuestions400JSONResponse)
		if !ok {
			t.Fatalf("expected GetQuestions400JSONResponse, got %T", resp)
		}
	})

	t.Run("invalid negative offset", func(t *testing.T) {
		offset := -1
		resp, err := h.GetQuestions(context.Background(), api.GetQuestionsRequestObject{
			Params: api.GetQuestionsParams{Offset: &offset},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		_, ok := resp.(api.GetQuestions400JSONResponse)
		if !ok {
			t.Fatalf("expected GetQuestions400JSONResponse, got %T", resp)
		}
	})
}

func TestGetQuestion(t *testing.T) {
	h := New(testDB, "https://cdn.example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})

	t.Run("existing question", func(t *testing.T) {
		var dbID int64
		err := testDB.QueryRow("SELECT id FROM questions ORDER BY id LIMIT 1").Scan(&dbID)
		if err != nil {
			t.Skip("no questions in DB")
		}

		resp, err := h.GetQuestion(context.Background(), api.GetQuestionRequestObject{
			QuestionId: dbID,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res, ok := resp.(api.GetQuestion200JSONResponse)
		if !ok {
			t.Fatalf("expected GetQuestion200JSONResponse, got %T", resp)
		}
		if res.Id != dbID {
			t.Errorf("expected ID %d, got %d", dbID, res.Id)
		}
		if res.Text == "" {
			t.Error("expected text to be non-empty")
		}
		if len(res.Choices) == 0 {
			t.Error("expected choices to be non-empty")
		}
	})

	t.Run("not found", func(t *testing.T) {
		resp, err := h.GetQuestion(context.Background(), api.GetQuestionRequestObject{
			QuestionId: 999999999,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res, ok := resp.(api.GetQuestion404JSONResponse)
		if !ok {
			t.Fatalf("expected GetQuestion404JSONResponse, got %T", resp)
		}
		if res.Code != "NOT_FOUND" {
			t.Errorf("expected code 'NOT_FOUND', got '%s'", res.Code)
		}
	})
}

func TestGetWorkbooks(t *testing.T) {
	h := New(testDB, "https://cdn.example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})

	t.Run("default", func(t *testing.T) {
		resp, err := h.GetWorkbooks(context.Background(), api.GetWorkbooksRequestObject{})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res, ok := resp.(api.GetWorkbooks200JSONResponse)
		if !ok {
			t.Fatalf("expected GetWorkbooks200JSONResponse, got %T", resp)
		}

		if res.Total == 0 {
			t.Fatal("expected total > 0")
		}
		if len(res.Workbooks) == 0 {
			t.Fatal("expected workbooks to be non-empty")
		}

		w := res.Workbooks[0]
		if w.Title == "" {
			t.Error("expected workbook title to be non-empty")
		}
		if w.QuestionCount == nil || *w.QuestionCount == 0 {
			t.Error("expected question count > 0")
		}
	})

	t.Run("invalid limit", func(t *testing.T) {
		limit := -5
		resp, err := h.GetWorkbooks(context.Background(), api.GetWorkbooksRequestObject{
			Params: api.GetWorkbooksParams{Limit: &limit},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		_, ok := resp.(api.GetWorkbooks400JSONResponse)
		if !ok {
			t.Fatalf("expected GetWorkbooks400JSONResponse, got %T", resp)
		}
	})
}

func TestGetWorkbook(t *testing.T) {
	h := New(testDB, "https://cdn.example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})

	t.Run("existing workbook", func(t *testing.T) {
		var dbID int64
		err := testDB.QueryRow("SELECT id FROM workbooks ORDER BY id LIMIT 1").Scan(&dbID)
		if err != nil {
			t.Skip("no workbooks in DB")
		}

		resp, err := h.GetWorkbook(context.Background(), api.GetWorkbookRequestObject{
			WorkbookId: dbID,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res, ok := resp.(api.GetWorkbook200JSONResponse)
		if !ok {
			t.Fatalf("expected GetWorkbook200JSONResponse, got %T", resp)
		}
		if res.Title == "" {
			t.Error("expected title to be non-empty")
		}
		if len(res.Questions) == 0 {
			t.Error("expected questions to be non-empty")
		}
	})

	t.Run("not found", func(t *testing.T) {
		resp, err := h.GetWorkbook(context.Background(), api.GetWorkbookRequestObject{
			WorkbookId: 999999999,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		res, ok := resp.(api.GetWorkbook404JSONResponse)
		if !ok {
			t.Fatalf("expected GetWorkbook404JSONResponse, got %T", resp)
		}
		if res.Code != "NOT_FOUND" {
			t.Errorf("expected code 'NOT_FOUND', got '%s'", res.Code)
		}
	})
}

func TestGetQuestionsWithImages(t *testing.T) {
	h := New(testDB, "https://cdn.example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{})

	// Fetch enough questions to find some with images
	limit := 100
	resp, err := h.GetQuestions(context.Background(), api.GetQuestionsRequestObject{
		Params: api.GetQuestionsParams{Limit: &limit},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	res := resp.(api.GetQuestions200JSONResponse)
	found := false
	for _, q := range res.Questions {
		if q.Images != nil && len(*q.Images) > 0 {
			found = true
			for _, url := range *q.Images {
				if len(url) < 10 {
					t.Errorf("expected valid URL, got '%s'", url)
				}
				if url[:len("https://cdn.example.com/")] != "https://cdn.example.com/" {
					t.Errorf("expected URL to start with base URL, got '%s'", url)
				}
			}
			break
		}
	}
	if !found {
		t.Log("no questions with images found in first 100 questions")
	}
}
