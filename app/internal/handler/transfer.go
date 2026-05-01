package handler

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/db"
)

func (h *Handler) IssueTransferToken(ctx context.Context, request api.IssueTransferTokenRequestObject) (api.IssueTransferTokenResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.IssueTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	token, err := generateToken()
	if err != nil {
		h.logger.Error("failed to generate transfer token", "error", err)
		return api.IssueTransferToken500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to generate token"}, nil
	}

	expiresAt := time.Now().Add(15 * time.Minute)
	err = h.queries.CreateTransferToken(ctx, db.CreateTransferTokenParams{
		Token:      token,
		IdentityID: deviceID,
		ExpiresAt:  expiresAt,
	})
	if err != nil {
		h.logger.Error("failed to create transfer token", "error", err)
		return api.IssueTransferToken500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to create token"}, nil
	}

	return api.IssueTransferToken200JSONResponse{
		Token:     token,
		ExpiresAt: expiresAt,
	}, nil
}

func (h *Handler) ApplyTransferToken(ctx context.Context, request api.ApplyTransferTokenRequestObject) (api.ApplyTransferTokenResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}
	if request.Body == nil || request.Body.Token == "" {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "token is required"}, nil
	}

	identityID, err := h.queries.ConsumeTransferToken(ctx, request.Body.Token)
	if err != nil {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_TOKEN", Message: "token is invalid or expired"}, nil
	}

	return api.ApplyTransferToken200JSONResponse{IdentityId: identityID}, nil
}

func generateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
