package handler

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"time"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/db"
)

const transferTokenTTL = 3 * 365 * 24 * time.Hour

func (h *Handler) GetTransferToken(ctx context.Context, request api.GetTransferTokenRequestObject) (api.GetTransferTokenResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.GetTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	// 既存の有効なトークンがあればそれを返す
	row, err := h.queries.GetActiveTransferToken(ctx, deviceID)
	if err == nil {
		return api.GetTransferToken200JSONResponse{Token: row.Token, ExpiresAt: row.ExpiresAt}, nil
	}
	if err != sql.ErrNoRows {
		h.logger.Error("failed to get transfer token", "error", err)
		return api.GetTransferToken500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to get token"}, nil
	}

	// なければ新規発行
	token, expiresAt, err := h.issueNewToken(ctx, deviceID)
	if err != nil {
		return api.GetTransferToken500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to create token"}, nil
	}
	return api.GetTransferToken200JSONResponse{Token: token, ExpiresAt: expiresAt}, nil
}

func (h *Handler) IssueTransferToken(ctx context.Context, request api.IssueTransferTokenRequestObject) (api.IssueTransferTokenResponseObject, error) {
	deviceID := request.Params.XDeviceID
	if deviceID == "" {
		return api.IssueTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	// 古いトークンをすべて削除してから新規発行
	if err := h.queries.DeleteTransferTokensByIdentityID(ctx, deviceID); err != nil {
		h.logger.Error("failed to delete old transfer tokens", "error", err)
		return api.IssueTransferToken500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to refresh token"}, nil
	}

	token, expiresAt, err := h.issueNewToken(ctx, deviceID)
	if err != nil {
		return api.IssueTransferToken500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to create token"}, nil
	}
	return api.IssueTransferToken200JSONResponse{Token: token, ExpiresAt: expiresAt}, nil
}

func (h *Handler) ApplyTransferToken(ctx context.Context, request api.ApplyTransferTokenRequestObject) (api.ApplyTransferTokenResponseObject, error) {
	if request.Params.XDeviceID == "" {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}
	if request.Body == nil || request.Body.Token == "" {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_PARAMETER", Message: "token is required"}, nil
	}

	// トークンの発行元 identity を確認（消費前にチェック）
	sourceIdentityID, err := h.queries.GetTransferTokenIdentityID(ctx, request.Body.Token)
	if err != nil {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_TOKEN", Message: "token is invalid or expired"}, nil
	}
	if sourceIdentityID == request.Params.XDeviceID {
		return api.ApplyTransferToken400JSONResponse{Code: "SAME_DEVICE", Message: "cannot apply token issued by the same device"}, nil
	}

	identityID, err := h.queries.ConsumeTransferToken(ctx, request.Body.Token)
	if err != nil {
		return api.ApplyTransferToken400JSONResponse{Code: "INVALID_TOKEN", Message: "token is invalid or expired"}, nil
	}

	return api.ApplyTransferToken200JSONResponse{IdentityId: identityID}, nil
}

func (h *Handler) issueNewToken(ctx context.Context, identityID string) (string, time.Time, error) {
	tokenStr, err := generateToken()
	if err != nil {
		h.logger.Error("failed to generate transfer token", "error", err)
		return "", time.Time{}, err
	}

	expiresAt := time.Now().Add(transferTokenTTL)
	row, err := h.queries.CreateTransferToken(ctx, db.CreateTransferTokenParams{
		Token:      tokenStr,
		IdentityID: identityID,
		ExpiresAt:  expiresAt,
	})
	if err != nil {
		h.logger.Error("failed to create transfer token", "error", err)
		return "", time.Time{}, err
	}

	return row.Token, row.ExpiresAt, nil
}

func generateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
