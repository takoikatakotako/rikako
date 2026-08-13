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
//
// セキュリティ: X-Device-ID はクライアント指定で所有証明ではないため、対象 users 行を
// FOR UPDATE でロックし、既に別アカウントへ紐付いている場合は 409 で拒否する（横取り防止）。
// なお未リンクの匿名行の所有検証（短命リンクトークン等）は follow-up（設計 §5.6 / #283）。
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

	fail := func(msg string, err error) (api.LinkAccountResponseObject, error) {
		h.logger.Error(msg, "error", err)
		return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
	}
	conflict := api.LinkAccount409JSONResponse{Code: "DEVICE_ALREADY_LINKED", Message: "device is linked to another account"}

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		return fail("failed to begin tx", err)
	}
	defer func() { _ = tx.Rollback() }()
	q := h.queries.WithTx(tx)

	// 端末の匿名 users 行を確保し、ロックして現在の account_id を読む。
	deviceUserID, err := q.UpsertUser(ctx, deviceID)
	if err != nil {
		return fail("failed to upsert device user", err)
	}
	deviceAccountID, err := q.GetUserAccountIDForUpdate(ctx, deviceUserID)
	if err != nil {
		return fail("failed to lock device user", err)
	}

	acct, err := q.GetAccountByCognitoSub(ctx, sub)
	accountExists := err == nil
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return fail("failed to get account", err)
	}

	// 端末が既にどこかのアカウントに紐付いている場合。
	// （所有証明のない X-Device-ID で他アカウントのデータを移動＝横取りを防ぐ。CreateAccount 前に判定する。）
	if deviceAccountID.Valid {
		if accountExists && deviceAccountID.Int64 == acct.ID {
			// 既にこのアカウントに紐付いている → 冪等 no-op。
			return commitLink(tx, acct.ID, acct.Email)
		}
		return conflict, nil
	}

	// 端末は未リンク。アカウントが無ければ並行安全に作成（この端末が primary）。
	if !accountExists {
		created, cerr := q.CreateAccountIfNotExists(ctx, db.CreateAccountIfNotExistsParams{
			CognitoSub:    sub,
			Email:         email,
			PrimaryUserID: deviceUserID,
		})
		switch {
		case errors.Is(cerr, sql.ErrNoRows):
			// 並行初回リンクで負けた側: 既存アカウントを再取得してマージ経路へ。
			acct, err = q.GetAccountByCognitoSub(ctx, sub)
			if err != nil {
				return fail("failed to refetch account after conflict", err)
			}
		case cerr != nil:
			return fail("failed to create account", cerr)
		default:
			if serr := q.SetUserAccountID(ctx, db.SetUserAccountIDParams{
				AccountID: sql.NullInt64{Int64: created.ID, Valid: true},
				ID:        deviceUserID,
			}); serr != nil {
				return fail("failed to set account id", serr)
			}
			return commitLink(tx, created.ID, created.Email)
		}
	}

	// 既存アカウント + 未リンク端末 → primary へマージ（deviceUser == primary なら no-op＝冪等）。
	if deviceUserID != acct.PrimaryUserID {
		if merr := q.RepointUserAnswersToUser(ctx, db.RepointUserAnswersToUserParams{
			Dst: acct.PrimaryUserID,
			Src: deviceUserID,
		}); merr != nil {
			return fail("failed to repoint user answers", merr)
		}
		// user_app_settings は (user_id, app_id) 衝突時 primary 側を優先（ON CONFLICT DO NOTHING）し、
		// source 側は削除する。同一 app の設定が両方にある場合、source の値は破棄される（仕様）。
		if merr := q.MoveUserAppSettingsToUser(ctx, db.MoveUserAppSettingsToUserParams{
			Dst: acct.PrimaryUserID,
			Src: deviceUserID,
		}); merr != nil {
			return fail("failed to move user app settings", merr)
		}
		if merr := q.DeleteUserAppSettingsByUser(ctx, deviceUserID); merr != nil {
			return fail("failed to delete moved app settings", merr)
		}
		if serr := q.SetUserAccountID(ctx, db.SetUserAccountIDParams{
			AccountID: sql.NullInt64{Int64: acct.ID, Valid: true},
			ID:        deviceUserID,
		}); serr != nil {
			return fail("failed to set account id", serr)
		}
	}

	return commitLink(tx, acct.ID, acct.Email)
}

func commitLink(tx *sql.Tx, accountID int64, email sql.NullString) (api.LinkAccountResponseObject, error) {
	if err := tx.Commit(); err != nil {
		return api.LinkAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to link account"}, nil
	}
	resp := api.LinkAccount200JSONResponse{AccountId: accountID}
	if email.Valid {
		e := email.String
		resp.Email = &e
	}
	return resp, nil
}
