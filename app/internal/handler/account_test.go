package handler

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/auth"
	"github.com/takoikatakotako/rikako/internal/identity"
	"github.com/takoikatakotako/rikako/internal/openai"
)

func newTestHandler() *Handler {
	return New(testDB, "https://example.com", "1.0.0", "1.0.0", testLogger, &identity.MockProvider{}, openai.NewClient(""), "")
}

func ctxWithSub(sub string) context.Context {
	return context.WithValue(context.Background(), auth.UserSubContextKey, sub)
}

func userIDByIdentity(t *testing.T, identityID string) int64 {
	t.Helper()
	var id int64
	if err := testDB.QueryRow(`SELECT id FROM users WHERE identity_id = $1`, identityID).Scan(&id); err != nil {
		t.Fatalf("user by identity %q: %v", identityID, err)
	}
	return id
}

func linkAccount(t *testing.T, h *Handler, sub, deviceID string) api.LinkAccount200JSONResponse {
	t.Helper()
	resp, err := h.LinkAccount(ctxWithSub(sub), api.LinkAccountRequestObject{
		Params: api.LinkAccountParams{XDeviceID: deviceID},
	})
	if err != nil {
		t.Fatalf("LinkAccount error: %v", err)
	}
	ok, isOK := resp.(api.LinkAccount200JSONResponse)
	if !isOK {
		t.Fatalf("expected LinkAccount200JSONResponse, got %T (%+v)", resp, resp)
	}
	return ok
}

func TestLinkAccount_CreateIdempotentAndMerge(t *testing.T) {
	h := newTestHandler()

	prefix := fmt.Sprintf("linktest-%d", time.Now().UnixNano())
	sub := prefix + "-sub"
	dev1 := prefix + "-dev1"
	dev2 := prefix + "-dev2"

	// cleanup
	defer func() {
		testDB.Exec(`DELETE FROM user_answers WHERE user_id IN (SELECT id FROM users WHERE identity_id LIKE $1)`, prefix+"%")
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub = $1`, sub)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
	}()

	// 1) 初リンク: アカウント作成、dev1 の user が primary。
	first := linkAccount(t, h, sub, dev1)
	if first.AccountId == 0 {
		t.Fatal("accountId is 0 after first link")
	}
	dev1User := userIDByIdentity(t, dev1)

	var primary int64
	var acctID int64
	if err := testDB.QueryRow(`SELECT id, primary_user_id FROM accounts WHERE cognito_sub = $1`, sub).Scan(&acctID, &primary); err != nil {
		t.Fatalf("account lookup: %v", err)
	}
	if acctID != first.AccountId {
		t.Errorf("account id mismatch: resp=%d db=%d", first.AccountId, acctID)
	}
	if primary != dev1User {
		t.Errorf("primary_user_id = %d, want dev1 user %d", primary, dev1User)
	}
	// dev1 user は account に紐付く
	var dev1Acct int64
	if err := testDB.QueryRow(`SELECT COALESCE(account_id,0) FROM users WHERE id = $1`, dev1User).Scan(&dev1Acct); err != nil {
		t.Fatalf("dev1 account_id: %v", err)
	}
	if dev1Acct != acctID {
		t.Errorf("dev1 user account_id = %d, want %d", dev1Acct, acctID)
	}

	// 2) 冪等: 同じ端末で再リンクしても同じ account、壊れない。
	second := linkAccount(t, h, sub, dev1)
	if second.AccountId != first.AccountId {
		t.Errorf("idempotent link returned different account: %d != %d", second.AccountId, first.AccountId)
	}

	// 3) 別端末 dev2 に回答を積んでからリンク → primary へマージされる。
	dev2User, err := h.queries.UpsertUser(context.Background(), dev2)
	if err != nil {
		t.Fatalf("create dev2 user: %v", err)
	}
	// CI では importer 実行済みで question/workbook 1 が存在する前提。
	if _, err := testDB.Exec(
		`INSERT INTO user_answers (user_id, question_id, workbook_id, selected_choice, is_correct)
		 VALUES ($1, 1, 1, 0, true)`, dev2User); err != nil {
		t.Fatalf("insert dev2 answer: %v", err)
	}

	linkAccount(t, h, sub, dev2)

	// dev2 の回答は primary(dev1User) に付け替わっている。
	var movedToPrimary int
	if err := testDB.QueryRow(`SELECT COUNT(*) FROM user_answers WHERE user_id = $1`, primary).Scan(&movedToPrimary); err != nil {
		t.Fatalf("count primary answers: %v", err)
	}
	if movedToPrimary == 0 {
		t.Error("dev2 answer was not merged into primary user")
	}
	var leftOnDev2 int
	if err := testDB.QueryRow(`SELECT COUNT(*) FROM user_answers WHERE user_id = $1`, dev2User).Scan(&leftOnDev2); err != nil {
		t.Fatalf("count dev2 answers: %v", err)
	}
	if leftOnDev2 != 0 {
		t.Errorf("dev2 still has %d answers after merge; want 0", leftOnDev2)
	}
}

func TestLinkAccount_MissingSub(t *testing.T) {
	h := newTestHandler()
	resp, err := h.LinkAccount(context.Background(), api.LinkAccountRequestObject{
		Params: api.LinkAccountParams{XDeviceID: "whatever"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(api.LinkAccount401JSONResponse); !ok {
		t.Fatalf("expected 401 when sub missing, got %T", resp)
	}
}
