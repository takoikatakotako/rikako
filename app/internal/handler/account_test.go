package handler

import (
	"context"
	"fmt"
	"sync"
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

// (a) 別アカウントに紐付いた Device-ID の拒否 + (d) 途中失敗時のロールバック。
// 既存アカウント A に紐付いた dev1 を、別 sub B のログイン中に指定すると 409。
// このとき B の account 作成は INSERT 済みでもトランザクションごとロールバックされる。
func TestLinkAccount_RejectCrossAccountAndRollback(t *testing.T) {
	h := newTestHandler()
	prefix := fmt.Sprintf("linkxacct-%d", time.Now().UnixNano())
	subA := prefix + "-subA"
	subB := prefix + "-subB"
	dev1 := prefix + "-dev1"

	defer func() {
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub IN ($1, $2)`, subA, subB)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
	}()

	a := linkAccount(t, h, subA, dev1)

	// dev1 を subB でリンクしようとすると 409。
	resp, err := h.LinkAccount(ctxWithSub(subB), api.LinkAccountRequestObject{
		Params: api.LinkAccountParams{XDeviceID: dev1},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if _, ok := resp.(api.LinkAccount409JSONResponse); !ok {
		t.Fatalf("expected 409 for cross-account device, got %T", resp)
	}

	// ロールバック: subB の account は作られていない。
	var cnt int
	if err := testDB.QueryRow(`SELECT COUNT(*) FROM accounts WHERE cognito_sub = $1`, subB).Scan(&cnt); err != nil {
		t.Fatalf("count subB accounts: %v", err)
	}
	if cnt != 0 {
		t.Errorf("account for subB was created despite 409 (rollback failed)")
	}
	// dev1 は依然 A に紐付いたまま。
	dev1User := userIDByIdentity(t, dev1)
	var dev1Acct int64
	if err := testDB.QueryRow(`SELECT COALESCE(account_id,0) FROM users WHERE id = $1`, dev1User).Scan(&dev1Acct); err != nil {
		t.Fatalf("dev1 account_id: %v", err)
	}
	if dev1Acct != a.AccountId {
		t.Errorf("dev1 account_id changed to %d; want %d (unchanged)", dev1Acct, a.AccountId)
	}
}

// (c) user_app_settings が同一 app_id で衝突したとき primary 側を優先する（source は破棄）。
func TestLinkAccount_SettingsPrimaryWins(t *testing.T) {
	h := newTestHandler()
	prefix := fmt.Sprintf("linkset-%d", time.Now().UnixNano())
	sub := prefix + "-sub"
	dev1 := prefix + "-dev1"
	dev2 := prefix + "-dev2"

	defer func() {
		testDB.Exec(`DELETE FROM user_app_settings WHERE user_id IN (SELECT id FROM users WHERE identity_id LIKE $1)`, prefix+"%")
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub = $1`, sub)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
	}()

	linkAccount(t, h, sub, dev1)
	primary := userIDByIdentity(t, dev1)
	// primary 側: app 1 = workbook 1
	if _, err := testDB.Exec(
		`INSERT INTO user_app_settings (user_id, app_id, selected_workbook_id) VALUES ($1, 1, 1)`, primary); err != nil {
		t.Fatalf("insert primary setting: %v", err)
	}
	// dev2 側: app 1 = workbook 2（衝突）
	dev2User, err := h.queries.UpsertUser(context.Background(), dev2)
	if err != nil {
		t.Fatalf("upsert dev2: %v", err)
	}
	if _, err := testDB.Exec(
		`INSERT INTO user_app_settings (user_id, app_id, selected_workbook_id) VALUES ($1, 1, 2)`, dev2User); err != nil {
		t.Fatalf("insert dev2 setting: %v", err)
	}

	linkAccount(t, h, sub, dev2)

	// primary の app 1 設定は 1 のまま（primary 優先）。
	var wb int64
	if err := testDB.QueryRow(
		`SELECT selected_workbook_id FROM user_app_settings WHERE user_id = $1 AND app_id = 1`, primary).Scan(&wb); err != nil {
		t.Fatalf("primary setting lookup: %v", err)
	}
	if wb != 1 {
		t.Errorf("primary app1 selected_workbook_id = %d; want 1 (primary wins)", wb)
	}
	// dev2 の設定は消えている。
	var dev2Cnt int
	if err := testDB.QueryRow(`SELECT COUNT(*) FROM user_app_settings WHERE user_id = $1`, dev2User).Scan(&dev2Cnt); err != nil {
		t.Fatalf("dev2 setting count: %v", err)
	}
	if dev2Cnt != 0 {
		t.Errorf("dev2 still has %d settings after merge; want 0", dev2Cnt)
	}
}

// (b) 同一 sub の並行初回リンクが冪等（両方 200・同一 account、500 を出さない）。
func TestLinkAccount_ConcurrentFirstLink(t *testing.T) {
	h := newTestHandler()
	prefix := fmt.Sprintf("linkconc-%d", time.Now().UnixNano())
	sub := prefix + "-sub"
	dev3 := prefix + "-dev3"
	dev4 := prefix + "-dev4"

	defer func() {
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub = $1`, sub)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
	}()

	var wg sync.WaitGroup
	results := make([]api.LinkAccountResponseObject, 2)
	errs := make([]error, 2)
	devices := []string{dev3, dev4}
	for i := range devices {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			results[idx], errs[idx] = h.LinkAccount(ctxWithSub(sub), api.LinkAccountRequestObject{
				Params: api.LinkAccountParams{XDeviceID: devices[idx]},
			})
		}(i)
	}
	wg.Wait()

	var accountIDs []int64
	for i := range devices {
		if errs[i] != nil {
			t.Fatalf("goroutine %d error: %v", i, errs[i])
		}
		ok, isOK := results[i].(api.LinkAccount200JSONResponse)
		if !isOK {
			t.Fatalf("goroutine %d: expected 200, got %T (%+v)", i, results[i], results[i])
		}
		accountIDs = append(accountIDs, ok.AccountId)
	}
	if accountIDs[0] != accountIDs[1] {
		t.Errorf("concurrent first-link produced different accounts: %d != %d", accountIDs[0], accountIDs[1])
	}
}

// ログイン中（JWT sub あり）は別の未リンク端末からでも account の primary データが見える。
// 未ログインの未リンク端末では空になる（＝解決が account 優先で端末に依らない）。
func TestResolveUserID_AccountAcrossDevices(t *testing.T) {
	h := newTestHandler()
	prefix := fmt.Sprintf("resolve-%d", time.Now().UnixNano())
	sub := prefix + "-sub"
	dev1 := prefix + "-dev1"
	dev2 := prefix + "-dev2"

	defer func() {
		testDB.Exec(`DELETE FROM user_answers WHERE user_id IN (SELECT id FROM users WHERE identity_id LIKE $1)`, prefix+"%")
		testDB.Exec(`DELETE FROM accounts WHERE cognito_sub = $1`, sub)
		testDB.Exec(`DELETE FROM users WHERE identity_id LIKE $1`, prefix+"%")
	}()

	linkAccount(t, h, sub, dev1)
	primary := userIDByIdentity(t, dev1)
	if _, err := testDB.Exec(
		`INSERT INTO user_answers (user_id, question_id, workbook_id, selected_choice, is_correct)
		 VALUES ($1, 1, 1, 0, true)`, primary); err != nil {
		t.Fatalf("insert answer: %v", err)
	}

	// (1) ログイン中 + 別の未リンク端末 dev2 → account primary のデータが見える。
	resp, err := h.GetUserSummary(ctxWithSub(sub), api.GetUserSummaryRequestObject{
		Params: api.GetUserSummaryParams{XDeviceID: dev2},
	})
	if err != nil {
		t.Fatalf("GetUserSummary(logged in): %v", err)
	}
	s, ok := resp.(api.GetUserSummary200JSONResponse)
	if !ok {
		t.Fatalf("expected 200, got %T", resp)
	}
	if s.TotalAnswered < 1 {
		t.Errorf("logged-in summary TotalAnswered=%d; want >=1 (account primary data)", s.TotalAnswered)
	}

	// (2) 未ログイン + dev2(未リンク) → 空。
	resp2, err := h.GetUserSummary(context.Background(), api.GetUserSummaryRequestObject{
		Params: api.GetUserSummaryParams{XDeviceID: dev2},
	})
	if err != nil {
		t.Fatalf("GetUserSummary(anon): %v", err)
	}
	s2, ok := resp2.(api.GetUserSummary200JSONResponse)
	if !ok {
		t.Fatalf("expected 200, got %T", resp2)
	}
	if s2.TotalAnswered != 0 {
		t.Errorf("anon dev2 summary TotalAnswered=%d; want 0", s2.TotalAnswered)
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
