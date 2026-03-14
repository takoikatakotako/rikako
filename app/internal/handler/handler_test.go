package handler

import (
	"context"
	"database/sql"
	"os"
	"testing"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/api"
)

var testDB *sql.DB

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
	h := New(testDB, "https://example.com")
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
	h := New(testDB, "https://example.com")
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
	h := New(testDB, "https://cdn.example.com")

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
		if q.Id == uuid.Nil {
			t.Error("expected question ID to be non-nil")
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
}

// TODO: GetQuestion / GetWorkbook の個別取得テストは #22 (UUID移行) 後に追加
// 現在はDBがBIGINT IDだがAPIはUUIDを受け取るためテスト不可

func TestGetWorkbooks(t *testing.T) {
	h := New(testDB, "https://cdn.example.com")

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
}


func TestGetQuestionsWithImages(t *testing.T) {
	h := New(testDB, "https://cdn.example.com")

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
