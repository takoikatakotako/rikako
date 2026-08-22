package handler

import (
	"context"
	"database/sql"
	"errors"

	"github.com/takoikatakotako/rikako/internal/auth"
)

// errAccountLinkRequired は、JWT の sub にまだ account が無く、かつ X-Device-ID が
// 別の account へリンク済みの場合に返す。
//
// この状態で device 側へフォールバックすると、B の有効な JWT を付けたリクエストが
// A の canonical データを読み書きしてしまう（別 sub による認可境界の越境）。
// クライアントは /account/link を先に済ませてから再試行する。
var errAccountLinkRequired = errors.New("account link required")

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
		// ログイン済みだが、この sub の account がまだ無い（link 前）。
		// 端末が別の account にリンク済みなら、そちらへフォールバックしてはいけない。
		if linked, lerr := h.deviceLinkedToAccount(ctx, deviceID); lerr != nil {
			return 0, false, lerr
		} else if linked {
			return 0, false, errAccountLinkRequired
		}
		// 未リンク端末 → 匿名 device のデータを見せる（link 前の自然な状態）。
		return h.userIDByDevice(ctx, deviceID)
	}

	// 未ログイン。リンク済み端末なら canonical user を使う。
	primaryUserID, err := h.queries.GetPrimaryUserIDByIdentityID(ctx, deviceID)
	if err == nil {
		return primaryUserID, true, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, false, err
	}

	return h.userIDByDevice(ctx, deviceID)
}

// userIDByDevice は X-Device-ID の users 行を引く（無ければ found=false）。
func (h *Handler) userIDByDevice(ctx context.Context, deviceID string) (int64, bool, error) {
	userID, err := h.queries.GetUserByIdentityID(ctx, deviceID)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	return userID, true, nil
}

// deviceLinkedToAccount は、その端末が既にいずれかの account へリンク済みかを返す。
func (h *Handler) deviceLinkedToAccount(ctx context.Context, deviceID string) (bool, error) {
	_, err := h.queries.GetPrimaryUserIDByIdentityID(ctx, deviceID)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return false, err
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
		// 読み取りと同じ理由で、別 account にリンク済みの端末へは書き込ませない。
		if linked, lerr := h.deviceLinkedToAccount(ctx, deviceID); lerr != nil {
			return 0, lerr
		} else if linked {
			return 0, errAccountLinkRequired
		}
		return h.queries.UpsertUser(ctx, deviceID)
	}

	// 未ログイン。リンク済み端末なら canonical user に入れる。
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
