package handler

import (
	"context"
	"database/sql"
	"errors"

	"github.com/takoikatakotako/rikako/internal/auth"
)

// resolveUserIDForRead は学習データ取得時の user_id を解決する（設計 §3.2）。
// ログイン中（JWT の sub があり account に紐付く）は account.primary_user_id を返し、
// 端末に依らず同じデータを見せる。そうでなければ X-Device-ID の users 行を引く。
// users 行が存在しなければ found=false を返す（各ハンドラが空/デフォルト応答を返す）。
func (h *Handler) resolveUserIDForRead(ctx context.Context, deviceID string) (int64, bool, error) {
	if sub, _ := ctx.Value(auth.UserSubContextKey).(string); sub != "" {
		acct, err := h.queries.GetAccountByCognitoSub(ctx, sub)
		if err == nil {
			return acct.PrimaryUserID, true, nil
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return 0, false, err
		}
		// ログイン済みだが未 link（account 未作成）→ 匿名 device にフォールバック。
	}
	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	return userID, true, nil
}

// resolveUserIDForWrite は書き込み時の user_id を解決する。
// ログイン中は account.primary_user_id、そうでなければ X-Device-ID の users 行を
// upsert（無ければ作成）して返す。
func (h *Handler) resolveUserIDForWrite(ctx context.Context, deviceID string) (int64, error) {
	if sub, _ := ctx.Value(auth.UserSubContextKey).(string); sub != "" {
		acct, err := h.queries.GetAccountByCognitoSub(ctx, sub)
		if err == nil {
			return acct.PrimaryUserID, nil
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return 0, err
		}
	}
	return h.queries.UpsertUser(ctx, deviceID)
}
