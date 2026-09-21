package handler

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/takoikatakotako/rikako/internal/api"
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
	if len(pool.Deleted) != 1 || pool.Deleted[0] != sub {
		t.Errorf("cognito delete calls = %v; want [%s]", pool.Deleted, sub)
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

func TestDeleteAccount_MissingSub(t *testing.T) {
	h := newTestHandler()
	resp, err := h.DeleteAccount(context.Background(), api.DeleteAccountRequestObject{})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := resp.(api.DeleteAccount401JSONResponse); !ok {
		t.Fatalf("expected 401, got %T", resp)
	}
}
