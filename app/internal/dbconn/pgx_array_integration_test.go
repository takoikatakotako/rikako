package dbconn_test

import (
	"database/sql"
	"os"
	"testing"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/dbconn"
)

// TestPgxSimpleProtocolArrayBinding は、pgx ドライバ + simple protocol の下で
// lib/pq の pq.Array による配列パラメータ束縛が機能することを実 DB に対して検証する。
//
// これは sqlc 生成コード（CreateUserAnswers 等）が使う
//
//	INSERT ... SELECT unnest($1::bigint[]), unnest($2::int[]), unnest($3::bool[])
//
// と同型で、lib/pq → pgx 移行（Issue #291）で最もリスクのある「配列パス」を担保する。
// DATABASE_URL 未設定時はスキップする（CI では postgres サービスに対して実行される）。
func TestPgxSimpleProtocolArrayBinding(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping DB integration test")
	}

	db, err := sql.Open("pgx", dbconn.SimpleProtocol(dsn))
	if err != nil {
		t.Fatalf("sql.Open(pgx): %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		t.Fatalf("ping: %v", err)
	}

	if _, err := db.Exec(`CREATE TEMP TABLE pgx_array_probe (a bigint, b int, c bool)`); err != nil {
		t.Fatalf("create temp table: %v", err)
	}

	questionIDs := []int64{101, 202, 303}
	selectedChoices := []int32{0, 1, 2}
	isCorrects := []bool{true, false, true}

	_, err = db.Exec(
		`INSERT INTO pgx_array_probe (a, b, c)
		 SELECT unnest($1::bigint[]), unnest($2::int[]), unnest($3::bool[])`,
		pq.Array(questionIDs), pq.Array(selectedChoices), pq.Array(isCorrects),
	)
	if err != nil {
		t.Fatalf("array insert via pq.Array under pgx simple protocol: %v", err)
	}

	var (
		count       int
		correctSum  int
		firstColSum int64
	)
	if err := db.QueryRow(
		`SELECT COUNT(*), COALESCE(SUM(CASE WHEN c THEN 1 ELSE 0 END),0), COALESCE(SUM(a),0) FROM pgx_array_probe`,
	).Scan(&count, &correctSum, &firstColSum); err != nil {
		t.Fatalf("read back: %v", err)
	}

	if count != 3 {
		t.Errorf("row count = %d, want 3", count)
	}
	if correctSum != 2 {
		t.Errorf("true count = %d, want 2", correctSum)
	}
	if firstColSum != 101+202+303 {
		t.Errorf("bigint sum = %d, want %d", firstColSum, int64(101+202+303))
	}
}
