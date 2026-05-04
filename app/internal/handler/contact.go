package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/takoikatakotako/rikako/internal/api"
)

func (h *Handler) SubmitContact(ctx context.Context, request api.SubmitContactRequestObject) (api.SubmitContactResponseObject, error) {
	if string(request.Params.XDeviceID) == "" {
		return api.SubmitContact400JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	if request.Body == nil || strings.TrimSpace(request.Body.Body) == "" {
		return api.SubmitContact400JSONResponse{Code: "INVALID_PARAMETER", Message: "body is required"}, nil
	}

	if h.slackWebhookURL == "" {
		h.logger.Warn("SLACK_WEBHOOK_URL not set, skipping notification")
		return api.SubmitContact204Response{}, nil
	}

	subject := "(件名なし)"
	if request.Body.Subject != nil && strings.TrimSpace(*request.Body.Subject) != "" {
		subject = *request.Body.Subject
	}

	email := "(希望なし)"
	if request.Body.Email != nil && strings.TrimSpace(*request.Body.Email) != "" {
		email = *request.Body.Email
	}

	userId := string(request.Params.XDeviceID)
	if request.Body.UserId != nil && strings.TrimSpace(*request.Body.UserId) != "" {
		userId = *request.Body.UserId
	}

	deviceInfo := ""
	if request.Body.DeviceModel != nil {
		deviceInfo += fmt.Sprintf("端末: %s", *request.Body.DeviceModel)
	}
	if request.Body.OsVersion != nil {
		deviceInfo += fmt.Sprintf(" / OS: %s", *request.Body.OsVersion)
	}
	if request.Body.AppVersion != nil {
		deviceInfo += fmt.Sprintf(" / App: %s", *request.Body.AppVersion)
	}

	text := fmt.Sprintf("【お問い合わせ】\n件名: %s\n返信先: %s\nユーザーID: %s\n環境: %s\n\n内容:\n%s",
		subject, email, userId, deviceInfo, request.Body.Body)
	payload, err := json.Marshal(map[string]string{"text": text})
	if err != nil {
		h.logger.Error("failed to marshal slack payload", "error", err)
		return nil, err
	}

	resp, err := http.Post(h.slackWebhookURL, "application/json", bytes.NewBuffer(payload))
	if err != nil {
		h.logger.Error("failed to post to slack", "error", err)
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		h.logger.Error("slack webhook returned non-200", "status", resp.StatusCode)
		return api.SubmitContact500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to send notification"}, nil
	}

	return api.SubmitContact204Response{}, nil
}
