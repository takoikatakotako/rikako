package admin

import (
	"context"
	"database/sql"
	"log/slog"
	"os"
	"testing"

	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/adminapi"
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

func newTestHandler() *Handler {
	return New(testDB, "https://example.com", nil, "", "", testLogger)
}

func TestRoot(t *testing.T) {
	h := newTestHandler()
	resp, err := h.Root(context.Background(), adminapi.RootRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	res, ok := resp.(adminapi.Root200JSONResponse)
	if !ok {
		t.Fatalf("expected Root200JSONResponse, got %T", resp)
	}
	if res.Message != "admin api running" {
		t.Errorf("expected 'admin api running', got '%s'", res.Message)
	}
}

func TestHealthCheck(t *testing.T) {
	h := newTestHandler()
	resp, err := h.HealthCheck(context.Background(), adminapi.HealthCheckRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	res, ok := resp.(adminapi.HealthCheck200JSONResponse)
	if !ok {
		t.Fatalf("expected HealthCheck200JSONResponse, got %T", resp)
	}
	if res.Status != "ok" {
		t.Errorf("expected 'ok', got '%s'", res.Status)
	}
}

func TestCreateAndGetQuestion(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	explanation := "test explanation"
	createResp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
		Body: &adminapi.CreateQuestionRequest{
			Type: adminapi.CreateQuestionRequestTypeSingleChoice,
			Text: "test question",
			Choices: []adminapi.Choice{
				{Text: "choice A", IsCorrect: true},
				{Text: "choice B", IsCorrect: false},
			},
			Explanation: &explanation,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	created, ok := createResp.(adminapi.CreateQuestion201JSONResponse)
	if !ok {
		t.Fatalf("expected CreateQuestion201JSONResponse, got %T", createResp)
	}
	if created.Id == 0 {
		t.Fatal("expected non-zero ID")
	}
	if created.Text != "test question" {
		t.Errorf("expected 'test question', got '%s'", created.Text)
	}
	if len(created.Choices) != 2 {
		t.Errorf("expected 2 choices, got %d", len(created.Choices))
	}
	if !created.Choices[0].IsCorrect {
		t.Error("expected first choice to be correct")
	}

	// Get
	getResp, err := h.GetQuestion(ctx, adminapi.GetQuestionRequestObject{QuestionId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got, ok := getResp.(adminapi.GetQuestion200JSONResponse)
	if !ok {
		t.Fatalf("expected GetQuestion200JSONResponse, got %T", getResp)
	}
	if got.Id != created.Id {
		t.Errorf("expected ID %d, got %d", created.Id, got.Id)
	}

	// Cleanup
	_, err = testDB.ExecContext(ctx, `DELETE FROM questions WHERE id = $1`, created.Id)
	if err != nil {
		t.Fatalf("cleanup failed: %v", err)
	}
}

func TestUpdateQuestion(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	// Create
	createResp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
		Body: &adminapi.CreateQuestionRequest{
			Type: adminapi.CreateQuestionRequestTypeSingleChoice,
			Text: "original text",
			Choices: []adminapi.Choice{
				{Text: "A", IsCorrect: true},
				{Text: "B", IsCorrect: false},
			},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateQuestion201JSONResponse)

	// Update
	updateResp, err := h.UpdateQuestion(ctx, adminapi.UpdateQuestionRequestObject{
		QuestionId: created.Id,
		Body: &adminapi.UpdateQuestionRequest{
			Type: adminapi.SingleChoice,
			Text: "updated text",
			Choices: []adminapi.Choice{
				{Text: "X", IsCorrect: false},
				{Text: "Y", IsCorrect: true},
				{Text: "Z", IsCorrect: false},
			},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	updated, ok := updateResp.(adminapi.UpdateQuestion200JSONResponse)
	if !ok {
		t.Fatalf("expected UpdateQuestion200JSONResponse, got %T", updateResp)
	}
	if updated.Text != "updated text" {
		t.Errorf("expected 'updated text', got '%s'", updated.Text)
	}
	if len(updated.Choices) != 3 {
		t.Errorf("expected 3 choices, got %d", len(updated.Choices))
	}

	// Cleanup
	testDB.ExecContext(ctx, `DELETE FROM questions WHERE id = $1`, created.Id)
}

func TestDeleteQuestion(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	// Create
	createResp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
		Body: &adminapi.CreateQuestionRequest{
			Type: adminapi.CreateQuestionRequestTypeSingleChoice,
			Text: "to delete",
			Choices: []adminapi.Choice{
				{Text: "A", IsCorrect: true},
				{Text: "B", IsCorrect: false},
			},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateQuestion201JSONResponse)

	// Delete
	delResp, err := h.DeleteQuestion(ctx, adminapi.DeleteQuestionRequestObject{QuestionId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := delResp.(adminapi.DeleteQuestion204Response); !ok {
		t.Fatalf("expected DeleteQuestion204Response, got %T", delResp)
	}

	// Verify deleted
	getResp, err := h.GetQuestion(ctx, adminapi.GetQuestionRequestObject{QuestionId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := getResp.(adminapi.GetQuestion404JSONResponse); !ok {
		t.Fatalf("expected 404 after delete, got %T", getResp)
	}
}

func TestDeleteQuestion_NotFound(t *testing.T) {
	h := newTestHandler()
	resp, err := h.DeleteQuestion(context.Background(), adminapi.DeleteQuestionRequestObject{QuestionId: 999999999})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(adminapi.DeleteQuestion404JSONResponse); !ok {
		t.Fatalf("expected DeleteQuestion404JSONResponse, got %T", resp)
	}
}

func TestCreateAndGetWorkbook(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	desc := "test description"
	createResp, err := h.CreateWorkbook(ctx, adminapi.CreateWorkbookRequestObject{
		Body: &adminapi.CreateWorkbookRequest{
			Title:       "test workbook",
			Description: &desc,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	created, ok := createResp.(adminapi.CreateWorkbook201JSONResponse)
	if !ok {
		t.Fatalf("expected CreateWorkbook201JSONResponse, got %T", createResp)
	}
	if created.Id == 0 {
		t.Fatal("expected non-zero ID")
	}
	if created.Title != "test workbook" {
		t.Errorf("expected 'test workbook', got '%s'", created.Title)
	}

	// Get
	getResp, err := h.GetWorkbook(ctx, adminapi.GetWorkbookRequestObject{WorkbookId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got, ok := getResp.(adminapi.GetWorkbook200JSONResponse)
	if !ok {
		t.Fatalf("expected GetWorkbook200JSONResponse, got %T", getResp)
	}
	if got.Title != "test workbook" {
		t.Errorf("expected 'test workbook', got '%s'", got.Title)
	}

	// Cleanup
	testDB.ExecContext(ctx, `DELETE FROM workbooks WHERE id = $1`, created.Id)
}

func TestGetWorkbook_IncludesQuestionsAndChoices(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	questionResp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
		Body: &adminapi.CreateQuestionRequest{
			Type: adminapi.CreateQuestionRequestTypeSingleChoice,
			Text: "workbook question",
			Choices: []adminapi.Choice{
				{Text: "A", IsCorrect: false},
				{Text: "B", IsCorrect: true},
			},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error creating question: %v", err)
	}
	createdQuestion := questionResp.(adminapi.CreateQuestion201JSONResponse)

	workbookResp, err := h.CreateWorkbook(ctx, adminapi.CreateWorkbookRequestObject{
		Body: &adminapi.CreateWorkbookRequest{
			Title:       "detail workbook",
			QuestionIds: &[]int64{createdQuestion.Id},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error creating workbook: %v", err)
	}
	createdWorkbook := workbookResp.(adminapi.CreateWorkbook201JSONResponse)

	getResp, err := h.GetWorkbook(ctx, adminapi.GetWorkbookRequestObject{WorkbookId: createdWorkbook.Id})
	if err != nil {
		t.Fatalf("unexpected error getting workbook: %v", err)
	}
	got, ok := getResp.(adminapi.GetWorkbook200JSONResponse)
	if !ok {
		t.Fatalf("expected GetWorkbook200JSONResponse, got %T", getResp)
	}
	if len(got.Questions) != 1 {
		t.Fatalf("expected 1 question, got %d", len(got.Questions))
	}
	if got.Questions[0].Text != "workbook question" {
		t.Fatalf("expected question text to match, got %q", got.Questions[0].Text)
	}
	if len(got.Questions[0].Choices) != 2 {
		t.Fatalf("expected 2 choices, got %d", len(got.Questions[0].Choices))
	}
	if !got.Questions[0].Choices[1].IsCorrect {
		t.Fatal("expected second choice to be correct")
	}

	testDB.ExecContext(ctx, `DELETE FROM workbooks WHERE id = $1`, createdWorkbook.Id)
	testDB.ExecContext(ctx, `DELETE FROM questions WHERE id = $1`, createdQuestion.Id)
}

func TestUpdateWorkbook(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	createResp, err := h.CreateWorkbook(ctx, adminapi.CreateWorkbookRequestObject{
		Body: &adminapi.CreateWorkbookRequest{Title: "original"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateWorkbook201JSONResponse)

	desc := "updated desc"
	updateResp, err := h.UpdateWorkbook(ctx, adminapi.UpdateWorkbookRequestObject{
		WorkbookId: created.Id,
		Body: &adminapi.UpdateWorkbookRequest{
			Title:       "updated title",
			Description: &desc,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	updated, ok := updateResp.(adminapi.UpdateWorkbook200JSONResponse)
	if !ok {
		t.Fatalf("expected UpdateWorkbook200JSONResponse, got %T", updateResp)
	}
	if updated.Title != "updated title" {
		t.Errorf("expected 'updated title', got '%s'", updated.Title)
	}

	testDB.ExecContext(ctx, `DELETE FROM workbooks WHERE id = $1`, created.Id)
}

func TestDeleteWorkbook(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	createResp, err := h.CreateWorkbook(ctx, adminapi.CreateWorkbookRequestObject{
		Body: &adminapi.CreateWorkbookRequest{Title: "to delete"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateWorkbook201JSONResponse)

	delResp, err := h.DeleteWorkbook(ctx, adminapi.DeleteWorkbookRequestObject{WorkbookId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := delResp.(adminapi.DeleteWorkbook204Response); !ok {
		t.Fatalf("expected DeleteWorkbook204Response, got %T", delResp)
	}

	// Verify deleted
	getResp, err := h.GetWorkbook(ctx, adminapi.GetWorkbookRequestObject{WorkbookId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := getResp.(adminapi.GetWorkbook404JSONResponse); !ok {
		t.Fatalf("expected 404 after delete, got %T", getResp)
	}
}

func TestDeleteWorkbook_NotFound(t *testing.T) {
	h := newTestHandler()
	resp, err := h.DeleteWorkbook(context.Background(), adminapi.DeleteWorkbookRequestObject{WorkbookId: 999999999})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(adminapi.DeleteWorkbook404JSONResponse); !ok {
		t.Fatalf("expected DeleteWorkbook404JSONResponse, got %T", resp)
	}
}

func TestCreatePresignedUrl_NoS3(t *testing.T) {
	h := newTestHandler() // s3Client is nil
	resp, err := h.CreatePresignedUrl(context.Background(), adminapi.CreatePresignedUrlRequestObject{
		Body: &adminapi.CreatePresignedUrlRequest{
			Filename:    "test.png",
			ContentType: adminapi.Imagepng,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	res, ok := resp.(adminapi.CreatePresignedUrl400JSONResponse)
	if !ok {
		t.Fatalf("expected CreatePresignedUrl400JSONResponse, got %T", resp)
	}
	if res.Code != "NOT_CONFIGURED" {
		t.Errorf("expected code 'NOT_CONFIGURED', got '%s'", res.Code)
	}
}

func TestCreateQuestion_Validation(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	t.Run("too few choices", func(t *testing.T) {
		resp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
			Body: &adminapi.CreateQuestionRequest{
				Type:    adminapi.CreateQuestionRequestTypeSingleChoice,
				Text:    "q",
				Choices: []adminapi.Choice{{Text: "A", IsCorrect: true}},
			},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if _, ok := resp.(adminapi.CreateQuestion400JSONResponse); !ok {
			t.Fatalf("expected 400, got %T", resp)
		}
	})

	t.Run("no correct choice", func(t *testing.T) {
		resp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
			Body: &adminapi.CreateQuestionRequest{
				Type: adminapi.CreateQuestionRequestTypeSingleChoice,
				Text: "q",
				Choices: []adminapi.Choice{
					{Text: "A", IsCorrect: false},
					{Text: "B", IsCorrect: false},
				},
			},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if _, ok := resp.(adminapi.CreateQuestion400JSONResponse); !ok {
			t.Fatalf("expected 400, got %T", resp)
		}
	})
}

func TestGetQuestions_Pagination(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	t.Run("invalid limit", func(t *testing.T) {
		limit := 0
		resp, err := h.GetQuestions(ctx, adminapi.GetQuestionsRequestObject{
			Params: adminapi.GetQuestionsParams{Limit: &limit},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if _, ok := resp.(adminapi.GetQuestions400JSONResponse); !ok {
			t.Fatalf("expected 400, got %T", resp)
		}
	})

	t.Run("negative offset", func(t *testing.T) {
		offset := -1
		resp, err := h.GetQuestions(ctx, adminapi.GetQuestionsRequestObject{
			Params: adminapi.GetQuestionsParams{Offset: &offset},
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if _, ok := resp.(adminapi.GetQuestions400JSONResponse); !ok {
			t.Fatalf("expected 400, got %T", resp)
		}
	})
}

func TestGetQuestions_IncludesChoices(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	beforeResp, err := h.GetQuestions(ctx, adminapi.GetQuestionsRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	before := beforeResp.(adminapi.GetQuestions200JSONResponse)

	createResp, err := h.CreateQuestion(ctx, adminapi.CreateQuestionRequestObject{
		Body: &adminapi.CreateQuestionRequest{
			Type: adminapi.CreateQuestionRequestTypeSingleChoice,
			Text: "list question",
			Choices: []adminapi.Choice{
				{Text: "A", IsCorrect: false},
				{Text: "B", IsCorrect: true},
			},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateQuestion201JSONResponse)

	limit := 1
	offset := before.Total
	resp, err := h.GetQuestions(ctx, adminapi.GetQuestionsRequestObject{
		Params: adminapi.GetQuestionsParams{Limit: &limit, Offset: &offset},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got, ok := resp.(adminapi.GetQuestions200JSONResponse)
	if !ok {
		t.Fatalf("expected GetQuestions200JSONResponse, got %T", resp)
	}
	if len(got.Questions) == 0 {
		t.Fatal("expected at least one question")
	}
	target := got.Questions[0]
	if target.Id != created.Id {
		t.Fatalf("expected created question %d, got %d", created.Id, target.Id)
	}
	if len(target.Choices) != 2 {
		t.Fatalf("expected 2 choices, got %d", len(target.Choices))
	}
	if !target.Choices[1].IsCorrect {
		t.Fatal("expected second choice to be correct")
	}

	testDB.ExecContext(ctx, `DELETE FROM questions WHERE id = $1`, created.Id)
}
