package handler

import (
	"context"
	"database/sql"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/db"
)

func (h *Handler) GetUserProfile(ctx context.Context, request api.GetUserProfileRequestObject) (api.GetUserProfileResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.GetUserProfile400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}
	appSlug := request.Params.XAppSlug
	if appSlug == "" {
		return api.GetUserProfile400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-App-Slug is required"}, nil
	}

	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if err == sql.ErrNoRows {
		return api.GetUserProfile200JSONResponse{IdentityId: deviceID}, nil
	}
	if err != nil {
		h.logger.Error("failed to get user", "error", err, "device_id", deviceID)
		return nil, err
	}

	profile, err := h.queries.GetUserProfile(ctx, userID)
	if err != nil {
		h.logger.Error("failed to get user profile", "error", err, "user_id", userID)
		return nil, err
	}

	resp := api.UserProfile{
		UserId:     &profile.ID,
		IdentityId: profile.IdentityID,
	}
	if profile.DisplayName.Valid {
		resp.DisplayName = &profile.DisplayName.String
	}

	// Get app-specific setting
	app, err := h.queries.GetAppBySlug(ctx, appSlug)
	if err == sql.ErrNoRows {
		return api.GetUserProfile200JSONResponse(resp), nil
	}
	if err != nil {
		h.logger.Error("failed to get app", "error", err, "slug", appSlug)
		return nil, err
	}

	setting, err := h.queries.GetUserAppSetting(ctx, db.GetUserAppSettingParams{
		UserID: userID,
		AppID:  app.ID,
	})
	if err == sql.ErrNoRows {
		return api.GetUserProfile200JSONResponse(resp), nil
	}
	if err != nil {
		h.logger.Error("failed to get user app setting", "error", err)
		return nil, err
	}
	if setting.SelectedWorkbookID.Valid {
		wbID := setting.SelectedWorkbookID.Int64
		resp.SelectedWorkbookId = &wbID
	}

	return api.GetUserProfile200JSONResponse(resp), nil
}

func (h *Handler) UpdateUserProfile(ctx context.Context, request api.UpdateUserProfileRequestObject) (api.UpdateUserProfileResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.UpdateUserProfile400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}
	appSlug := request.Params.XAppSlug
	if appSlug == "" {
		return api.UpdateUserProfile400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-App-Slug is required"}, nil
	}
	if request.Body == nil {
		return api.UpdateUserProfile400JSONResponse{Code: "INVALID_PARAMETER", Message: "request body is required"}, nil
	}

	// Upsert user
	userID, err := h.queries.UpsertUser(ctx, deviceID)
	if err != nil {
		h.logger.Error("failed to upsert user", "error", err, "device_id", deviceID)
		return nil, err
	}

	// Update display name if provided
	if request.Body.DisplayName != nil {
		err = h.queries.UpdateUserDisplayName(ctx, db.UpdateUserDisplayNameParams{
			DisplayName: sql.NullString{String: *request.Body.DisplayName, Valid: true},
			ID:          userID,
		})
		if err != nil {
			h.logger.Error("failed to update display name", "error", err)
			return nil, err
		}
	}

	// Update selected workbook if provided
	if request.Body.SelectedWorkbookId != nil {
		app, err := h.queries.GetAppBySlug(ctx, appSlug)
		if err == sql.ErrNoRows {
			return api.UpdateUserProfile400JSONResponse{Code: "INVALID_PARAMETER", Message: "app not found"}, nil
		}
		if err != nil {
			h.logger.Error("failed to get app", "error", err, "slug", appSlug)
			return nil, err
		}

		err = h.queries.UpsertUserAppSetting(ctx, db.UpsertUserAppSettingParams{
			UserID:             userID,
			AppID:              app.ID,
			SelectedWorkbookID: sql.NullInt64{Int64: *request.Body.SelectedWorkbookId, Valid: true},
		})
		if err != nil {
			h.logger.Error("failed to upsert user app setting", "error", err)
			return nil, err
		}
	}

	// Re-fetch and return updated profile
	profile, err := h.queries.GetUserProfile(ctx, userID)
	if err != nil {
		h.logger.Error("failed to get updated profile", "error", err)
		return nil, err
	}

	resp := api.UserProfile{
		UserId:     &profile.ID,
		IdentityId: profile.IdentityID,
	}
	if profile.DisplayName.Valid {
		resp.DisplayName = &profile.DisplayName.String
	}

	// Fetch app setting for response
	app, err := h.queries.GetAppBySlug(ctx, appSlug)
	if err == nil {
		setting, err := h.queries.GetUserAppSetting(ctx, db.GetUserAppSettingParams{
			UserID: userID,
			AppID:  app.ID,
		})
		if err == nil && setting.SelectedWorkbookID.Valid {
			wbID := setting.SelectedWorkbookID.Int64
			resp.SelectedWorkbookId = &wbID
		}
	}

	return api.UpdateUserProfile200JSONResponse(resp), nil
}
