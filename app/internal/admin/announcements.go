package admin

import (
	"context"
	"database/sql"
	"strings"
	"time"

	"github.com/takoikatakotako/rikako/internal/adminapi"
	"github.com/takoikatakotako/rikako/internal/db"
)

func toAdminAnnouncement(row db.Announcement) adminapi.Announcement {
	return adminapi.Announcement{
		Id:          row.ID,
		Title:       row.Title,
		Body:        row.Body,
		Category:    row.Category,
		PublishedAt: row.PublishedAt,
	}
}

func (h *Handler) GetAnnouncements(ctx context.Context, request adminapi.GetAnnouncementsRequestObject) (adminapi.GetAnnouncementsResponseObject, error) {
	limit, offset, err := validatePagination(request.Params.Limit, request.Params.Offset)
	if err != nil {
		return adminapi.GetAnnouncements400JSONResponse{Code: "INVALID_PARAMETER", Message: err.Error()}, nil
	}

	total, err := h.queries.CountAnnouncements(ctx)
	if err != nil {
		h.logger.Error("failed to count announcements", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListAnnouncements(ctx, db.ListAnnouncementsParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		h.logger.Error("failed to list announcements", "error", err)
		return nil, err
	}

	items := []adminapi.Announcement{}
	for _, row := range rows {
		items = append(items, toAdminAnnouncement(row))
	}

	return adminapi.GetAnnouncements200JSONResponse{Announcements: items, Total: int(total)}, nil
}

func (h *Handler) GetAnnouncement(ctx context.Context, request adminapi.GetAnnouncementRequestObject) (adminapi.GetAnnouncementResponseObject, error) {
	row, err := h.queries.GetAnnouncement(ctx, request.AnnouncementId)
	if err == sql.ErrNoRows {
		return adminapi.GetAnnouncement404JSONResponse{Code: "NOT_FOUND", Message: "announcement not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get announcement", "error", err, "announcement_id", request.AnnouncementId)
		return nil, err
	}
	return adminapi.GetAnnouncement200JSONResponse(toAdminAnnouncement(row)), nil
}

func (h *Handler) CreateAnnouncement(ctx context.Context, request adminapi.CreateAnnouncementRequestObject) (adminapi.CreateAnnouncementResponseObject, error) {
	if request.Body == nil {
		return adminapi.CreateAnnouncement400JSONResponse{Code: "INVALID_PARAMETER", Message: "request body is required"}, nil
	}
	body := request.Body

	if strings.TrimSpace(body.Title) == "" {
		return adminapi.CreateAnnouncement400JSONResponse{Code: "INVALID_PARAMETER", Message: "title is required"}, nil
	}
	if strings.TrimSpace(body.Body) == "" {
		return adminapi.CreateAnnouncement400JSONResponse{Code: "INVALID_PARAMETER", Message: "body is required"}, nil
	}

	category := "info"
	if body.Category != nil && *body.Category != "" {
		category = *body.Category
	}
	publishedAt := time.Now()
	if body.PublishedAt != nil {
		publishedAt = *body.PublishedAt
	}

	id, err := h.queries.CreateAnnouncement(ctx, db.CreateAnnouncementParams{
		Title:       body.Title,
		Body:        body.Body,
		Category:    category,
		PublishedAt: publishedAt,
	})
	if err != nil {
		h.logger.Error("failed to create announcement", "error", err)
		return nil, err
	}

	row, err := h.queries.GetAnnouncement(ctx, id)
	if err != nil {
		h.logger.Error("failed to get created announcement", "error", err)
		return nil, err
	}

	return adminapi.CreateAnnouncement201JSONResponse(toAdminAnnouncement(row)), nil
}

func (h *Handler) UpdateAnnouncement(ctx context.Context, request adminapi.UpdateAnnouncementRequestObject) (adminapi.UpdateAnnouncementResponseObject, error) {
	if request.Body == nil {
		return adminapi.UpdateAnnouncement400JSONResponse{Code: "INVALID_PARAMETER", Message: "request body is required"}, nil
	}
	body := request.Body

	if strings.TrimSpace(body.Title) == "" {
		return adminapi.UpdateAnnouncement400JSONResponse{Code: "INVALID_PARAMETER", Message: "title is required"}, nil
	}
	if strings.TrimSpace(body.Body) == "" {
		return adminapi.UpdateAnnouncement400JSONResponse{Code: "INVALID_PARAMETER", Message: "body is required"}, nil
	}

	existing, err := h.queries.GetAnnouncement(ctx, request.AnnouncementId)
	if err == sql.ErrNoRows {
		return adminapi.UpdateAnnouncement404JSONResponse{Code: "NOT_FOUND", Message: "announcement not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get announcement", "error", err, "announcement_id", request.AnnouncementId)
		return nil, err
	}

	category := existing.Category
	if body.Category != nil && *body.Category != "" {
		category = *body.Category
	}
	publishedAt := existing.PublishedAt
	if body.PublishedAt != nil {
		publishedAt = *body.PublishedAt
	}

	err = h.queries.UpdateAnnouncement(ctx, db.UpdateAnnouncementParams{
		ID:          request.AnnouncementId,
		Title:       body.Title,
		Body:        body.Body,
		Category:    category,
		PublishedAt: publishedAt,
	})
	if err != nil {
		h.logger.Error("failed to update announcement", "error", err)
		return nil, err
	}

	row, err := h.queries.GetAnnouncement(ctx, request.AnnouncementId)
	if err != nil {
		h.logger.Error("failed to get updated announcement", "error", err)
		return nil, err
	}

	return adminapi.UpdateAnnouncement200JSONResponse(toAdminAnnouncement(row)), nil
}

func (h *Handler) DeleteAnnouncement(ctx context.Context, request adminapi.DeleteAnnouncementRequestObject) (adminapi.DeleteAnnouncementResponseObject, error) {
	result, err := h.queries.DeleteAnnouncement(ctx, request.AnnouncementId)
	if err != nil {
		h.logger.Error("failed to delete announcement", "error", err, "announcement_id", request.AnnouncementId)
		return nil, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, err
	}
	if rowsAffected == 0 {
		return adminapi.DeleteAnnouncement404JSONResponse{Code: "NOT_FOUND", Message: "announcement not found"}, nil
	}

	return adminapi.DeleteAnnouncement204Response{}, nil
}
