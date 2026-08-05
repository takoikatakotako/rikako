package handler

import (
	"context"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/appslug"
)

func (h *Handler) GetAppStatus(ctx context.Context, request api.GetAppStatusRequestObject) (api.GetAppStatusResponseObject, error) {
	row, err := h.queries.GetAppStatus(ctx)
	if err != nil {
		h.logger.Error("failed to get app status", "error", err)
		return nil, err
	}

	// minimumVersion/latestVersion は app_slug 別に上書きできる。
	// X-App-Slug が指定され、対応する env（例: MINIMUM_VERSION_IT_PASSPORT）が
	// あればそれを、無ければグローバル既定を返す。ヘッダ未指定の旧アプリは既定にフォールバック。
	slug := appslug.FromContext(ctx)

	return api.GetAppStatus200JSONResponse{
		MinimumVersion:     appslug.VersionOverride(h.minimumVersion, "MINIMUM_VERSION", slug),
		LatestVersion:      appslug.VersionOverride(h.latestVersion, "LATEST_VERSION", slug),
		IsMaintenance:      row.IsMaintenance,
		MaintenanceMessage: row.MaintenanceMessage,
	}, nil
}
