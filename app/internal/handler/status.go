package handler

import (
	"context"

	"github.com/takoikatakotako/rikako/internal/api"
)

func (h *Handler) GetAppStatus(ctx context.Context, request api.GetAppStatusRequestObject) (api.GetAppStatusResponseObject, error) {
	row, err := h.queries.GetAppStatus(ctx)
	if err != nil {
		h.logger.Error("failed to get app status", "error", err)
		return nil, err
	}

	return api.GetAppStatus200JSONResponse{
		MinimumVersion:     h.minimumVersion,
		LatestVersion:      h.latestVersion,
		IsMaintenance:      row.IsMaintenance,
		MaintenanceMessage: row.MaintenanceMessage,
	}, nil
}
