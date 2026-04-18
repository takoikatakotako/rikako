package admin

import (
	"context"

	"github.com/takoikatakotako/rikako/internal/adminapi"
	"github.com/takoikatakotako/rikako/internal/db"
)

func (h *Handler) GetAppStatus(ctx context.Context, request adminapi.GetAppStatusRequestObject) (adminapi.GetAppStatusResponseObject, error) {
	row, err := h.queries.GetAppStatus(ctx)
	if err != nil {
		h.logger.Error("failed to get app status", "error", err)
		return nil, err
	}

	return adminapi.GetAppStatus200JSONResponse{
		IsMaintenance:      row.IsMaintenance,
		MaintenanceMessage: row.MaintenanceMessage,
		UpdatedAt:          row.UpdatedAt,
	}, nil
}

func (h *Handler) UpdateAppStatus(ctx context.Context, request adminapi.UpdateAppStatusRequestObject) (adminapi.UpdateAppStatusResponseObject, error) {
	if request.Body == nil {
		return adminapi.UpdateAppStatus400JSONResponse{Code: "INVALID_PARAMETER", Message: "request body is required"}, nil
	}

	err := h.queries.UpdateAppStatus(ctx, db.UpdateAppStatusParams{
		IsMaintenance:      request.Body.IsMaintenance,
		MaintenanceMessage: request.Body.MaintenanceMessage,
	})
	if err != nil {
		h.logger.Error("failed to update app status", "error", err)
		return nil, err
	}

	row, err := h.queries.GetAppStatus(ctx)
	if err != nil {
		h.logger.Error("failed to get app status after update", "error", err)
		return nil, err
	}

	return adminapi.UpdateAppStatus200JSONResponse{
		IsMaintenance:      row.IsMaintenance,
		MaintenanceMessage: row.MaintenanceMessage,
		UpdatedAt:          row.UpdatedAt,
	}, nil
}
