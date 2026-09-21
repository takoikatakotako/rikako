package handler

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/auth"
	"github.com/takoikatakotako/rikako/internal/userpool"
)

func deleteAccount(t *testing.T, h *Handler, sub string) api.DeleteAccountResponseObject {
	t.Helper()
	resp, err := h.DeleteAccount(ctxWithSub(sub), api.DeleteAccountRequestObject{})
	if err != nil {
		t.Fatalf("DeleteAccount error: %v", err)
	}
	return resp
}

func countRows(t *testing.T, query string, args ...any) int {
	t.Helper()
	var n int
	if err := testDB.QueryRow(query, args...).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	return n
}

// アカウント削除で、束ねられた全端末の users / 回答 / 設定が消え、Cognito 側の削除も呼ばれる（#408）。
func TestDeleteAccount_RemovesAllLinkedDataAndCognitoUser(t *testing.T) {
	h := newTestHandler()
	pool := &userpool.NoopDeleter{}
	h.WithUserPool(pool)

	prefix := fmt.Sprintf("deltest-%d", time.Now().UnixNano())
	sub := prefix + "-sub"
	dev1 := prefix + "-dev1"
	dev2 := prefix + "-dev2"
	defer func() {
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub = $1`, sub)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
		testDB.Exec(`DELETE FROM transfer_tokens WHERE identity_id LIKE $1`, prefix+"%")
		testDB.Exec(`DELETE FROM deleted_accounts WHERE cognito_sub = $1`, sub)
	}()

	// 2 端末を同じアカウントに束ね、両方に回答と設定を持たせる。
	linkAccount(t, h, sub, dev1)
	linkAccount(t, h, sub, dev2)
	primary := userIDByIdentity(t, dev1)
	insertAnswer(t, primary)
	if _, err := testDB.Exec(
		`INSERT INTO user_app_settings (user_id, app_id, selected_workbook_id) VALUES ($1, 1, 1)`, primary); err != nil {
		t.Fatalf("insert settings: %v", err)
	}
	for _, dev := range []string{dev1, dev2} {
		if _, err := testDB.Exec(
			`INSERT INTO transfer_tokens (token, identity_id, expires_at) VALUES ($1, $2, CURRENT_TIMESTAMP + INTERVAL '3 years')`,
			prefix+"-tok-"+dev, dev); err != nil {
			t.Fatalf("insert transfer token: %v", err)
		}
	}
	if n := countRows(t, `SELECT count(*) FROM users WHERE identity_id LIKE $1`, prefix+"%"); n != 2 {
		t.Fatalf("precondition: users = %d; want 2", n)
	}

	if resp := deleteAccount(t, h, sub); resp != (api.DeleteAccount204Response{}) {
		t.Fatalf("expected 204, got %T (%+v)", resp, resp)
	}

	if n := countRows(t, `SELECT count(*) FROM accounts WHERE cognito_sub = $1`, sub); n != 0 {
		t.Errorf("accounts remaining = %d", n)
	}
	if n := countRows(t, `SELECT count(*) FROM users WHERE identity_id LIKE $1`, prefix+"%"); n != 0 {
		t.Errorf("users remaining = %d", n)
	}
	if n := countRows(t, `SELECT count(*) FROM user_answers WHERE user_id = $1`, primary); n != 0 {
		t.Errorf("user_answers remaining = %d", n)
	}
	if n := countRows(t, `SELECT count(*) FROM user_app_settings WHERE user_id = $1`, primary); n != 0 {
		t.Errorf("user_app_settings remaining = %d", n)
	}
	if len(pool.Deleted) != 1 || pool.Deleted[0] != sub+"-name" {
		t.Errorf("cognito delete calls = %v; want [%s-name] (cognito:username, not sub)", pool.Deleted, sub)
	}
	if n := countRows(t, `SELECT count(*) FROM transfer_tokens WHERE identity_id IN ($1, $2)`, dev1, dev2); n != 0 {
		t.Errorf("transfer_tokens remaining = %d", n)
	}
	if n := countRows(t, `SELECT count(*) FROM deleted_accounts WHERE cognito_sub = $1`, sub); n != 1 {
		t.Errorf("tombstone rows = %d; want 1", n)
	}

	// 冪等: DB に無くても Cognito の削除を試みて 204。
	if resp := deleteAccount(t, h, sub); resp != (api.DeleteAccount204Response{}) {
		t.Fatalf("second delete: expected 204, got %T", resp)
	}
	if len(pool.Deleted) != 2 {
		t.Errorf("cognito delete should be retried on repeat; calls = %d", len(pool.Deleted))
	}
}

// 他アカウントのデータには触らない。
func TestDeleteAccount_DoesNotTouchOtherAccounts(t *testing.T) {
	h := newTestHandler()
	h.WithUserPool(&userpool.NoopDeleter{})

	prefix := fmt.Sprintf("deltest2-%d", time.Now().UnixNano())
	subA, subB := prefix+"-subA", prefix+"-subB"
	devA, devB := prefix+"-devA", prefix+"-devB"
	defer func() {
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub IN ($1, $2)`, subA, subB)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
		testDB.Exec(`DELETE FROM deleted_accounts WHERE cognito_sub IN ($1, $2)`, subA, subB)
	}()
	linkAccount(t, h, subA, devA)
	linkAccount(t, h, subB, devB)
	insertAnswer(t, userIDByIdentity(t, devB))

	deleteAccount(t, h, subA)

	if n := countRows(t, `SELECT count(*) FROM accounts WHERE cognito_sub = $1`, subB); n != 1 {
		t.Errorf("account B removed")
	}
	if n := countRows(t, `SELECT count(*) FROM user_answers WHERE user_id = $1`, userIDByIdentity(t, devB)); n != 1 {
		t.Errorf("answers of B removed")
	}
}

func TestDeleteAccount_MissingSubOrUsername(t *testing.T) {
	h := newTestHandler()
	for name, ctx := range map[string]context.Context{
		"no claims":   context.Background(),
		"sub only":    context.WithValue(context.Background(), auth.UserSubContextKey, "x"),
		"no username": context.WithValue(context.WithValue(context.Background(), auth.UserSubContextKey, "x"), auth.UserNameContextKey, ""),
	} {
		resp, err := h.DeleteAccount(ctx, api.DeleteAccountRequestObject{})
		if err != nil {
			t.Fatal(err)
		}
		if _, ok := resp.(api.DeleteAccount401JSONResponse); !ok {
			t.Errorf("%s: expected 401, got %T", name, resp)
		}
	}
}

// 削除後、期限内の ID token で /account/link されても再作成しない（墓標、#408）。
func TestDeleteAccount_LinkAfterDeleteIsRejected(t *testing.T) {
	h := newTestHandler()
	h.WithUserPool(&userpool.NoopDeleter{})

	prefix := fmt.Sprintf("deltest3-%d", time.Now().UnixNano())
	sub := prefix + "-sub"
	dev1, dev2 := prefix+"-dev1", prefix+"-dev2"
	defer func() {
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub = $1`, sub)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
		testDB.Exec(`DELETE FROM deleted_accounts WHERE cognito_sub = $1`, sub)
	}()
	linkAccount(t, h, sub, dev1)
	deleteAccount(t, h, sub)

	// 同じ端末・別の端末のどちらからでも拒否される。
	for _, dev := range []string{dev1, dev2} {
		resp, err := h.LinkAccount(ctxWithSub(sub), api.LinkAccountRequestObject{Params: api.LinkAccountParams{XDeviceID: dev}})
		if err != nil {
			t.Fatal(err)
		}
		r, ok := resp.(api.LinkAccount401JSONResponse)
		if !ok || r.Code != "ACCOUNT_DELETED" {
			t.Errorf("link after delete (%s): got %T %+v; want 401 ACCOUNT_DELETED", dev, resp, resp)
		}
	}
	if n := countRows(t, `SELECT count(*) FROM accounts WHERE cognito_sub = $1`, sub); n != 0 {
		t.Errorf("account recreated after delete")
	}
}

// link と delete が並行しても、delete 完了時点でその sub の accounts / users が残らない（#408）。
// アドバイザリロックで直列化されるので、どちらの順で走っても最終状態は同じ。
func TestDeleteAccount_ConcurrentLinkDoesNotResurrect(t *testing.T) {
	h := newTestHandler()
	h.WithUserPool(&userpool.NoopDeleter{})

	for round := 0; round < 5; round++ {
		prefix := fmt.Sprintf("deltest4-%d-%d", time.Now().UnixNano(), round)
		sub := prefix + "-sub"
		dev1 := prefix + "-dev1"
		linkAccount(t, h, sub, dev1)

		// 複数の別端末からの link と delete を同時に投げる。
		var wg sync.WaitGroup
		devs := []string{prefix + "-dev2", prefix + "-dev3", prefix + "-dev4"}
		wg.Add(len(devs) + 1)
		for _, dev := range devs {
			go func(dev string) {
				defer wg.Done()
				_, _ = h.LinkAccount(ctxWithSub(sub), api.LinkAccountRequestObject{Params: api.LinkAccountParams{XDeviceID: dev}})
			}(dev)
		}
		go func() {
			defer wg.Done()
			deleteAccount(t, h, sub)
		}()
		wg.Wait()

		// 遅れて到着した link も拒否されるので、最終的に account も紐付き users も存在しない。
		if n := countRows(t, `SELECT count(*) FROM accounts WHERE cognito_sub = $1`, sub); n != 0 {
			t.Errorf("round %d: account exists after delete", round)
		}
		if n := countRows(t, `SELECT count(*) FROM users u JOIN accounts a ON a.id = u.account_id WHERE a.cognito_sub = $1`, sub); n != 0 {
			t.Errorf("round %d: linked users exist after delete", round)
		}
		// delete より先に link した端末の users 行は消え、delete より後に link を試みた端末の
		// 匿名 users 行（UpsertUser 済み）は account_id NULL のまま残る。どちらも紐付き無し。
		if n := countRows(t, `SELECT count(*) FROM users WHERE identity_id LIKE $1 AND account_id IS NOT NULL`, prefix+"%"); n != 0 {
			t.Errorf("round %d: users still bound to an account", round)
		}

		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
		testDB.Exec(`DELETE FROM deleted_accounts WHERE cognito_sub = $1`, sub)
	}
}
