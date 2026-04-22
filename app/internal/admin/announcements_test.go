package admin

import (
	"context"
	"testing"
	"time"

	"github.com/takoikatakotako/rikako/internal/adminapi"
)

func TestCreateAndGetAnnouncement(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	category := "release"
	publishedAt := time.Now().Add(-1 * time.Hour).UTC().Truncate(time.Second)
	createResp, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{
			Title:       "v1.1.0 リリース",
			Body:        "# 新機能\n- お知らせ機能を追加",
			Category:    &category,
			PublishedAt: &publishedAt,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created, ok := createResp.(adminapi.CreateAnnouncement201JSONResponse)
	if !ok {
		t.Fatalf("expected CreateAnnouncement201JSONResponse, got %T", createResp)
	}
	defer h.DeleteAnnouncement(ctx, adminapi.DeleteAnnouncementRequestObject{AnnouncementId: created.Id})

	if created.Title != "v1.1.0 リリース" {
		t.Errorf("unexpected title: %s", created.Title)
	}
	if created.Category != "release" {
		t.Errorf("unexpected category: %s", created.Category)
	}

	getResp, err := h.GetAnnouncement(ctx, adminapi.GetAnnouncementRequestObject{AnnouncementId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got, ok := getResp.(adminapi.GetAnnouncement200JSONResponse)
	if !ok {
		t.Fatalf("expected GetAnnouncement200JSONResponse, got %T", getResp)
	}
	if got.Id != created.Id || got.Body != created.Body {
		t.Errorf("mismatch: %+v vs %+v", got, created)
	}
}

func TestCreateAnnouncement_DefaultsCategoryAndPublishedAt(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	before := time.Now().Add(-1 * time.Second)
	createResp, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{
			Title: "デフォルト値の確認",
			Body:  "category未指定",
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateAnnouncement201JSONResponse)
	defer h.DeleteAnnouncement(ctx, adminapi.DeleteAnnouncementRequestObject{AnnouncementId: created.Id})

	if created.Category != "info" {
		t.Errorf("expected default category 'info', got %q", created.Category)
	}
	if created.PublishedAt.Before(before) {
		t.Errorf("expected publishedAt >= %v, got %v", before, created.PublishedAt)
	}
}

func TestCreateAnnouncement_Validation(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	resp, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{Title: "", Body: "body"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(adminapi.CreateAnnouncement400JSONResponse); !ok {
		t.Errorf("expected 400 for empty title, got %T", resp)
	}

	resp, err = h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{Title: "title", Body: " \t\n"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(adminapi.CreateAnnouncement400JSONResponse); !ok {
		t.Errorf("expected 400 for blank body, got %T", resp)
	}
}

func TestUpdateAnnouncement(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	createResp, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{Title: "original", Body: "original body"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateAnnouncement201JSONResponse)
	defer h.DeleteAnnouncement(ctx, adminapi.DeleteAnnouncementRequestObject{AnnouncementId: created.Id})

	newCategory := "maintenance"
	updResp, err := h.UpdateAnnouncement(ctx, adminapi.UpdateAnnouncementRequestObject{
		AnnouncementId: created.Id,
		Body: &adminapi.UpdateAnnouncementRequest{
			Title:    "updated",
			Body:     "updated body",
			Category: &newCategory,
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	updated, ok := updResp.(adminapi.UpdateAnnouncement200JSONResponse)
	if !ok {
		t.Fatalf("expected UpdateAnnouncement200JSONResponse, got %T", updResp)
	}
	if updated.Title != "updated" || updated.Category != "maintenance" {
		t.Errorf("update not reflected: %+v", updated)
	}
}

func TestUpdateAnnouncement_NotFound(t *testing.T) {
	h := newTestHandler()
	resp, err := h.UpdateAnnouncement(context.Background(), adminapi.UpdateAnnouncementRequestObject{
		AnnouncementId: 999999999,
		Body:           &adminapi.UpdateAnnouncementRequest{Title: "x", Body: "y"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(adminapi.UpdateAnnouncement404JSONResponse); !ok {
		t.Errorf("expected 404, got %T", resp)
	}
}

func TestDeleteAnnouncement(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	createResp, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{Title: "to delete", Body: "body"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	created := createResp.(adminapi.CreateAnnouncement201JSONResponse)

	delResp, err := h.DeleteAnnouncement(ctx, adminapi.DeleteAnnouncementRequestObject{AnnouncementId: created.Id})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := delResp.(adminapi.DeleteAnnouncement204Response); !ok {
		t.Fatalf("expected 204, got %T", delResp)
	}

	getResp, _ := h.GetAnnouncement(ctx, adminapi.GetAnnouncementRequestObject{AnnouncementId: created.Id})
	if _, ok := getResp.(adminapi.GetAnnouncement404JSONResponse); !ok {
		t.Errorf("expected 404 after delete, got %T", getResp)
	}
}

func TestDeleteAnnouncement_NotFound(t *testing.T) {
	h := newTestHandler()
	resp, err := h.DeleteAnnouncement(context.Background(), adminapi.DeleteAnnouncementRequestObject{AnnouncementId: 999999999})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(adminapi.DeleteAnnouncement404JSONResponse); !ok {
		t.Errorf("expected 404, got %T", resp)
	}
}

func TestGetAnnouncements_ListOrder(t *testing.T) {
	h := newTestHandler()
	ctx := context.Background()

	older := time.Now().Add(-2 * time.Hour).UTC().Truncate(time.Second)
	newer := time.Now().Add(-1 * time.Hour).UTC().Truncate(time.Second)

	oldCreate, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{Title: "old", Body: "body", PublishedAt: &older},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	oldID := oldCreate.(adminapi.CreateAnnouncement201JSONResponse).Id
	defer h.DeleteAnnouncement(ctx, adminapi.DeleteAnnouncementRequestObject{AnnouncementId: oldID})

	newCreate, err := h.CreateAnnouncement(ctx, adminapi.CreateAnnouncementRequestObject{
		Body: &adminapi.CreateAnnouncementRequest{Title: "new", Body: "body", PublishedAt: &newer},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	newID := newCreate.(adminapi.CreateAnnouncement201JSONResponse).Id
	defer h.DeleteAnnouncement(ctx, adminapi.DeleteAnnouncementRequestObject{AnnouncementId: newID})

	listResp, err := h.GetAnnouncements(ctx, adminapi.GetAnnouncementsRequestObject{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	list := listResp.(adminapi.GetAnnouncements200JSONResponse)

	// Find positions in the list — newer must come before older.
	newPos, oldPos := -1, -1
	for i, a := range list.Announcements {
		if a.Id == newID {
			newPos = i
		}
		if a.Id == oldID {
			oldPos = i
		}
	}
	if newPos == -1 || oldPos == -1 {
		t.Fatalf("expected both announcements in list, new=%d old=%d", newPos, oldPos)
	}
	if newPos >= oldPos {
		t.Errorf("expected newer before older, but got newPos=%d oldPos=%d", newPos, oldPos)
	}
}
