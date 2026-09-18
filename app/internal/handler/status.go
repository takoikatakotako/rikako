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

	// Android は iOS と独立したバージョン体系を使う。プラットフォーム未指定の
	// 既存 iOS クライアントには従来の app_slug 別設定を適用する。
	slug := ""
	if request.Params.XAppSlug != nil {
		slug = *request.Params.XAppSlug
	}
	platform := ""
	if request.Params.XAppPlatform != nil {
		platform = string(*request.Params.XAppPlatform)
	}

	return api.GetAppStatus200JSONResponse{
		MinimumVersion:     appslug.PlatformVersionOverride(h.minimumVersion, "MINIMUM_VERSION", slug, platform),
		LatestVersion:      appslug.PlatformVersionOverride(h.latestVersion, "LATEST_VERSION", slug, platform),
		IsMaintenance:      row.IsMaintenance,
		MaintenanceMessage: row.MaintenanceMessage,
	}, nil
}
