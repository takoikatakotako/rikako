package handler

import (
	"context"
	"database/sql"
	"errors"
	"time"

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

	// DeleteAccount と直列化し、削除済み sub（墓標）なら拒否する（#408）。
	// Cognito のユーザーを消しても発行済み ID token は期限まで有効に見えるため、
	// ここで止めないと削除直後に accounts / users が再作成される。
	if err := q.LockAccountSub(ctx, sub); err != nil {
		return fail("failed to lock sub", err)
	}
	if deleted, err := q.IsAccountDeleted(ctx, sub); err != nil {
		return fail("failed to check deleted accounts", err)
	} else if deleted {
		return api.LinkAccount401JSONResponse{Code: "ACCOUNT_DELETED", Message: "account has been deleted"}, nil
	}

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

// GetAccountServices は認証済みアカウント（JWT の sub）が利用しているアプリ
// （IT / 化学など）の一覧を返す。ポータルのプロフィール表示に使う。認証必須。
func (h *Handler) GetAccountServices(ctx context.Context, request api.GetAccountServicesRequestObject) (api.GetAccountServicesResponseObject, error) {
	sub, _ := ctx.Value(auth.UserSubContextKey).(string)
	if sub == "" {
		// 認証必須（publicOperations 外）だが念のため防御。
		return api.GetAccountServices401JSONResponse{Code: "UNAUTHORIZED", Message: "authentication required"}, nil
	}

	acct, err := h.queries.GetAccountByCognitoSub(ctx, sub)
	if errors.Is(err, sql.ErrNoRows) {
		// ログイン済みだが未 link（account 未作成）→ 空。通常はポータルが先に /account/link を呼ぶ。
		return api.GetAccountServices200JSONResponse{Services: []api.ServiceItem{}}, nil
	}
	if err != nil {
		h.logger.Error("failed to get account", "error", err)
		return nil, err
	}

	rows, err := h.queries.ListUserAppSettings(ctx, acct.PrimaryUserID)
	if err != nil {
		h.logger.Error("failed to list user app settings", "error", err)
		return nil, err
	}
	services := make([]api.ServiceItem, len(rows))
	for i, r := range rows {
		services[i] = api.ServiceItem{Slug: r.AppSlug, Title: r.AppTitle}
	}
	return api.GetAccountServices200JSONResponse{Services: services}, nil
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

// DeleteAccount は認証済みアカウント（JWT の sub / cognito:username）を削除する（#408）。
//
// 1. DB（1 トランザクション、sub 単位のアドバイザリロック下）:
//   - deleted_accounts に墓標を残す（発行済み ID token による /account/link の再作成を拒否するため）
//   - accounts 行 → それに束ねられた全 users 行（primary 含む）の順で削除。
//     user_answers / user_app_settings は users の ON DELETE CASCADE。
//     accounts.primary_user_id は ON DELETE RESTRICT なので account → users の順
//   - 各端末の identity_id に紐づく transfer_tokens（FK 無し）も削除
//
// 2. Cognito User Pool のユーザーを AdminDeleteUser（DB コミット後、cognito:username で）
//
// 順序の理由: Cognito を先に消して DB が失敗すると、ユーザーは再ログインできず DB に
// 孤児が残る。DB を先に消して Cognito が失敗した場合は再ログインして再実行でき、
// その際 DB に account が無くても Cognito 側の削除だけを行うので冪等に収束する。
//
// LinkAccount とは LockAccountSub（pg_advisory_xact_lock）で直列化しているので、
// 進行中の link が読んだスナップショット外の users が残ることはない。
//
// 端末側は 204 を受けたらトークンと匿名 identity を破棄し、新しい匿名ユーザーとして
// やり直す（サーバーは端末の identity を知らないので、ここでは何もしない）。
func (h *Handler) DeleteAccount(ctx context.Context, _ api.DeleteAccountRequestObject) (api.DeleteAccountResponseObject, error) {
	sub, _ := ctx.Value(auth.UserSubContextKey).(string)
	username, _ := ctx.Value(auth.UserNameContextKey).(string)
	if sub == "" || username == "" {
		return api.DeleteAccount401JSONResponse{Code: "UNAUTHORIZED", Message: "authentication required"}, nil
	}
	fail := func(msg string, err error) (api.DeleteAccountResponseObject, error) {
		h.logger.Error(msg, "error", err)
		return api.DeleteAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "failed to delete account"}, nil
	}

	tx, err := h.db.BeginTx(ctx, nil)
	if err != nil {
		return fail("failed to begin tx", err)
	}
	defer func() { _ = tx.Rollback() }()
	q := h.queries.WithTx(tx)

	if err := q.LockAccountSub(ctx, sub); err != nil {
		return fail("failed to lock sub", err)
	}
	if err := q.MarkAccountDeleted(ctx, sub); err != nil {
		return fail("failed to mark account deleted", err)
	}
	// Cognito 削除確認から 7 日を過ぎた墓標を掃除する（毎日の backup-db-prod.yml でも掃除する）。
	if _, err := q.PurgeExpiredDeletedAccounts(ctx); err != nil {
		return fail("failed to purge expired tombstones", err)
	}

	acct, err := q.GetAccountByCognitoSub(ctx, sub)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		// DB 側は既に無い（前回の途中失敗、または一度も link していない）。墓標だけ残して Cognito を消す。
	case err != nil:
		return fail("failed to get account", err)
	default:
		users, lerr := q.ListUsersByAccountID(ctx, sql.NullInt64{Int64: acct.ID, Valid: true})
		if lerr != nil {
			return fail("failed to list account users", lerr)
		}
		userIDs := make([]int64, 0, len(users))
		identityIDs := make([]string, 0, len(users))
		for _, u := range users {
			userIDs = append(userIDs, u.ID)
			identityIDs = append(identityIDs, u.IdentityID)
		}
		if derr := q.DeleteAccountByID(ctx, acct.ID); derr != nil {
			return fail("failed to delete account", derr)
		}
		if len(userIDs) > 0 {
			if derr := q.DeleteTransferTokensByIdentityIDs(ctx, identityIDs); derr != nil {
				return fail("failed to delete transfer tokens", derr)
			}
			if derr := q.DeleteUsersByIDs(ctx, userIDs); derr != nil {
				return fail("failed to delete account users", derr)
			}
		}
		h.logger.Info("account deleted", "account_id", acct.ID, "users", len(userIDs))
	}
	if cerr := tx.Commit(); cerr != nil {
		return fail("failed to commit", cerr)
	}

	if err := h.userPool.DeleteUser(ctx, username); err != nil {
		// 墓標は cognito_deleted_at = NULL のまま残る（期限切れで消えない）。
		// ユーザーは Cognito に残っているので再ログインして再実行できる。
		return fail("failed to delete cognito user", err)
	}
	// Cognito 側の削除が確認できたので、墓標に確認時刻を入れる（これで 7 日後に期限切れになる）。
	// 失敗すると墓標が無期限に残るので握り潰さない: 数回リトライし、それでも駄目なら 500 を返す。
	// クライアントは ID token の有効期間内なら再実行でき（DB に account は無く、Cognito は
	// UserNotFound で成功扱い）、確認時刻だけが付く。ERROR ログは CloudWatch → Slack に流れる。
	var markErr error
	for attempt := 0; attempt < 3; attempt++ {
		if markErr = h.queries.MarkCognitoUserDeleted(ctx, sub); markErr == nil {
			break
		}
		time.Sleep(time.Duration(attempt+1) * 200 * time.Millisecond)
	}
	if markErr != nil {
		// sub はログに残さない（削除済み識別子の保持先を増やさない）。未確認の墓標は runbook のクエリで一覧できる。
		h.logger.Error("failed to mark cognito user deleted after retries (tombstone will not expire until retried)", "error", markErr)
		return api.DeleteAccount500JSONResponse{Code: "INTERNAL_ERROR", Message: "account deleted but cleanup incomplete; please retry"}, nil
	}
	return api.DeleteAccount204Response{}, nil
}
