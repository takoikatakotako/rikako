package handler

import (
	"context"
	"database/sql"
	"errors"

	"github.com/takoikatakotako/rikako/internal/auth"
)

// resolveUserIDForRead は学習データ取得時の user_id を解決する（設計 §3.2）。
// ログイン中（JWT の sub があり account に紐付く）は account.primary_user_id を返し、
// 端末に依らず同じデータを見せる。
//
// 未ログインでも、その端末が既にアカウントへ紐付いていれば canonical user を返す。
// ログアウトで device id を消さない設計なので、そうしないとリンク済み端末の
// ログアウト中の読み書きが device user 側に分かれてしまう。書き込みが分かれると、
// 再ログイン時の /account/link は同一アカウントに対して冪等 no-op なので回収されず、
// 「ログアウト中は見えるのにログインすると消える」記録が生まれる。
//
// どちらにも当てはまらなければ X-Device-ID の users 行を引く。
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
	// リンク済み端末なら、未ログインでもアカウントの canonical user を使う。
	primaryUserID, err := h.queries.GetPrimaryUserIDByIdentityID(ctx, deviceID)
	if err == nil {
		return primaryUserID, true, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, false, err
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
// ログイン中は account.primary_user_id、未ログインでも端末がアカウントへ
// 紐付いていれば canonical user（理由は resolveUserIDForRead を参照）。
// どちらでもなければ X-Device-ID の users 行を upsert（無ければ作成）して返す。
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
	// リンク済み端末なら、未ログインの書き込みも canonical user に入れる。
	// device user 側に溜めると、再ログイン時の冪等 no-op で回収されずに残る。
	primaryUserID, err := h.queries.GetPrimaryUserIDByIdentityID(ctx, deviceID)
	if err == nil {
		return primaryUserID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, err
	}

	return h.queries.UpsertUser(ctx, deviceID)
}
