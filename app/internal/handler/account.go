package handler

import (
	"context"
	"database/sql"
	"errors"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/auth"
	"github.com/takoikatakotako/rikako/internal/db"
)

// LinkAccount は Cognito User Pool ログイン後に呼ばれ、JWT の sub からアカウントを
// 解決（無ければ作成）し、X-Device-ID の匿名ユーザーの学習データを canonical user
// （accounts.primary_user_id）へマージする。冪等。
//
// マージ方針（設計 §5.2）: 初回リンク端末の匿名 users 行をそのまま primary にする。
// 以降の端末はその primary へマージする。
func (h *Handler) LinkAccount(ctx context.Context, request api.LinkAccountRequestObject) (api.LinkAccountResponseObject, error) {
	sub, _ := ctx.Value(auth.UserSubContextKey).(string)
	if sub == "" {
		// LinkAccount は認証必須（publicOperations 外）だが、念のため防御。
		return api.LinkAccount401JSONResponse{Code: "UNAUTHORIZED", Message: "authentication required"}, nil
	}

	deviceID := string(request.Params.XDeviceID)
	if deviceID == "" {
		return api.LinkAccount500JSONResponse{Code: "INVALID_PARAMETER", Message: "X-Device-ID is required"}, nil
	}

	var email sql.NullString
	if request.Body != nil && request.Body.Email != nil && *request.Body.Email != "" {
		email = sql.NullString{String: *request.Body.Email, Valid: true}
	}

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		h.logger.Error("failed to begin tx", "error", err)
		return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
	}
	defer func() { _ = tx.Rollback() }()
	q := h.queries.WithTx(tx)

	// 端末の匿名 users 行を確保。
	deviceUserID, err := q.UpsertUser(ctx, deviceID)
	if err != nil {
		h.logger.Error("failed to upsert device user", "error", err)
		return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
	}

	var accountID int64
	var accountEmail sql.NullString

	acct, err := q.GetAccountByCognitoSub(ctx, sub)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		// 初リンク: この端末の匿名 users 行を primary にしてアカウント作成。
		created, cerr := q.CreateAccount(ctx, db.CreateAccountParams{
			CognitoSub:    sub,
			Email:         email,
			PrimaryUserID: deviceUserID,
		})
		if cerr != nil {
			h.logger.Error("failed to create account", "error", cerr)
			return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
		}
		if serr := q.SetUserAccountID(ctx, db.SetUserAccountIDParams{
			AccountID: sql.NullInt64{Int64: created.ID, Valid: true},
			ID:        deviceUserID,
		}); serr != nil {
			h.logger.Error("failed to set account id", "error", serr)
			return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
		}
		accountID = created.ID
		accountEmail = created.Email

	case err != nil:
		h.logger.Error("failed to get account", "error", err)
		return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil

	default:
		// アカウント既存: 端末の匿名データを primary へマージ（deviceUser == primary なら何もしない＝冪等）。
		accountID = acct.ID
		accountEmail = acct.Email
		if deviceUserID != acct.PrimaryUserID {
			if merr := q.RepointUserAnswersToUser(ctx, db.RepointUserAnswersToUserParams{
				Dst: acct.PrimaryUserID,
				Src: deviceUserID,
			}); merr != nil {
				h.logger.Error("failed to repoint user answers", "error", merr)
				return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
			}
			if merr := q.MoveUserAppSettingsToUser(ctx, db.MoveUserAppSettingsToUserParams{
				Dst: acct.PrimaryUserID,
				Src: deviceUserID,
			}); merr != nil {
				h.logger.Error("failed to move user app settings", "error", merr)
				return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
			}
			if merr := q.DeleteUserAppSettingsByUser(ctx, deviceUserID); merr != nil {
				h.logger.Error("failed to delete moved app settings", "error", merr)
				return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
			}
			if serr := q.SetUserAccountID(ctx, db.SetUserAccountIDParams{
				AccountID: sql.NullInt64{Int64: accountID, Valid: true},
				ID:        deviceUserID,
			}); serr != nil {
				h.logger.Error("failed to set account id", "error", serr)
				return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
			}
		}
	}

	if err := tx.Commit(); err != nil {
		h.logger.Error("failed to commit link account tx", "error", err)
		return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
	}

	resp := api.LinkAccount200JSONResponse{AccountId: accountID}
	if accountEmail.Valid {
		e := accountEmail.String
		resp.Email = &e
	}
	return resp, nil
}
