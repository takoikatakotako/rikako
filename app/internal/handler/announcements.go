package handler

import (
	"context"
	"database/sql"

	"github.com/takoikatakotako/rikako/internal/api"
)

func (h *Handler) GetAnnouncements(ctx context.Context, _ api.GetAnnouncementsRequestObject) (api.GetAnnouncementsResponseObject, error) {
	rows, err := h.queries.ListLatestAnnouncements(ctx, 50)
	if err != nil {
		h.logger.Error("failed to list announcements", "error", err)
		return nil, err
	}

	items := []api.Announcement{}
	for _, row := range rows {
		items = append(items, api.Announcement{
			Id:          row.ID,
			Title:       row.Title,
			Body:        row.Body,
			Category:    row.Category,
			PublishedAt: row.PublishedAt,
		})
	}

	return api.GetAnnouncements200JSONResponse{Announcements: items, Total: len(items)}, nil
}

func (h *Handler) GetAnnouncement(ctx context.Context, request api.GetAnnouncementRequestObject) (api.GetAnnouncementResponseObject, error) {
	row, err := h.queries.GetAnnouncement(ctx, request.AnnouncementId)
	if err == sql.ErrNoRows {
		return api.GetAnnouncement404JSONResponse{Code: "NOT_FOUND", Message: "announcement not found"}, nil
	}
	if err != nil {
		h.logger.Error("failed to get announcement", "error", err, "announcement_id", request.AnnouncementId)
		return nil, err
	}
	return api.GetAnnouncement200JSONResponse{
		Id:          row.ID,
		Title:       row.Title,
		Body:        row.Body,
		Category:    row.Category,
		PublishedAt: row.PublishedAt,
	}, nil
}
