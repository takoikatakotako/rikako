package handler

import (
	"context"

	"github.com/takoikatakotako/rikako/internal/api"
)

func (h *Handler) AnonymousSignIn(ctx context.Context, request api.AnonymousSignInRequestObject) (api.AnonymousSignInResponseObject, error) {
	identityID, err := h.identityProvider.GetIdentityID(ctx)
	if err != nil {
		h.logger.Error("failed to get identity ID", "error", err)
		return api.AnonymousSignIn500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to create identity"}, nil
	}

	_, err = h.queries.UpsertUser(ctx, identityID)
	if err != nil {
		h.logger.Error("failed to upsert user", "error", err, "identity_id", identityID)
		return api.AnonymousSignIn500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to create user"}, nil
	}

	return api.AnonymousSignIn200JSONResponse{IdentityId: identityID}, nil
}

func (h *Handler) AnonymousSignOut(ctx context.Context, request api.AnonymousSignOutRequestObject) (api.AnonymousSignOutResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.AnonymousSignOut400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	return api.AnonymousSignOut204Response{}, nil
}
