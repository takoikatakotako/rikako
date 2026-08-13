// Package schematest は migration が作る DB 制約（特に認可境界に関わるもの）を実 DB で検証する。
// DATABASE_URL 未設定時は skip する（CI では postgres サービスに対して実行される）。
package schematest

import (
	"database/sql"
	"fmt"
	"os"
	"testing"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/takoikatakotako/rikako/internal/dbconn"
)

func openDB(t *testing.T) *sql.DB {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping schema constraint test")
	}
	db, err := sql.Open("pgx", dbconn.SimpleProtocol(dsn))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := db.Ping(); err != nil {
		t.Fatalf("ping: %v", err)
	}
	return db
}

func createUser(t *testing.T, db *sql.DB, identity string) int64 {
	t.Helper()
	var id int64
	if err := db.QueryRow(`INSERT INTO users (identity_id) VALUES ($1) RETURNING id`, identity).Scan(&id); err != nil {
		t.Fatalf("create user: %v", err)
	}
	return id
}

// TestAccountsConstraints は accounts テーブルの制約を検証する（#283）。
// 各アサーションは autocommit で実行し、テストで作成した行は最後に掃除する。
func TestAccountsConstraints(t *testing.T) {
	db := openDB(t)
	defer db.Close()

	prefix := fmt.Sprintf("schematest-%d", time.Now().UnixNano())
	u1 := createUser(t, db, prefix+"-u1")
	u2 := createUser(t, db, prefix+"-u2")

	acctIDs := []int64{}
	// cleanup: accounts を先に消す（primary_user_id は ON DELETE RESTRICT）。その後 users。
	defer func() {
		for _, id := range acctIDs {
			_, _ = db.Exec(`DELETE FROM accounts WHERE id = $1`, id)
		}
		_, _ = db.Exec(`DELETE FROM users WHERE id IN ($1, $2)`, u1, u2)
	}()

	subA := prefix + "-subA"

	var acctA int64
	if err := db.QueryRow(
		`INSERT INTO accounts (cognito_sub, primary_user_id) VALUES ($1, $2) RETURNING id`, subA, u1,
	).Scan(&acctA); err != nil {
		t.Fatalf("create account A: %v", err)
	}
	acctIDs = append(acctIDs, acctA)

	// 1. 同じ cognito_sub は作れない
	if _, err := db.Exec(
		`INSERT INTO accounts (cognito_sub, primary_user_id) VALUES ($1, $2)`, subA, u2,
	); err == nil {
		t.Error("duplicate cognito_sub was allowed; want unique violation")
	}

	// 2. 同じ primary_user_id を別 account へ割り当てられない（認可境界）
	if _, err := db.Exec(
		`INSERT INTO accounts (cognito_sub, primary_user_id) VALUES ($1, $2)`, prefix+"-subB", u1,
	); err == nil {
		t.Error("duplicate primary_user_id was allowed; want unique violation")
	}

	// 3. 1 account に複数の users.account_id を割り当てられる
	if _, err := db.Exec(`UPDATE users SET account_id = $1 WHERE id IN ($2, $3)`, acctA, u1, u2); err != nil {
		t.Fatalf("assign multiple users to one account: %v", err)
	}

	// 4. account 削除で users.account_id が NULL になる（ON DELETE SET NULL）
	if _, err := db.Exec(`DELETE FROM accounts WHERE id = $1`, acctA); err != nil {
		t.Fatalf("delete account A: %v", err)
	}
	acctIDs = acctIDs[:0] // acctA は削除済み
	var remaining int
	if err := db.QueryRow(
		`SELECT COUNT(*) FROM users WHERE id IN ($1, $2) AND account_id IS NOT NULL`, u1, u2,
	).Scan(&remaining); err != nil {
		t.Fatalf("check account_id null: %v", err)
	}
	if remaining != 0 {
		t.Errorf("account_id not set NULL after account delete: %d rows still set", remaining)
	}

	// 5. primary user の削除は ON DELETE RESTRICT で拒否される
	var acctC int64
	if err := db.QueryRow(
		`INSERT INTO accounts (cognito_sub, primary_user_id) VALUES ($1, $2) RETURNING id`, prefix+"-subC", u1,
	).Scan(&acctC); err != nil {
		t.Fatalf("create account C: %v", err)
	}
	acctIDs = append(acctIDs, acctC)
	if _, err := db.Exec(`DELETE FROM users WHERE id = $1`, u1); err == nil {
		t.Error("deleting primary user was allowed; want ON DELETE RESTRICT")
	}
}
