package main

import (
	"database/sql"
	"flag"
	"log"
	"os"

	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/importer"
)

func main() {
	dataDir := flag.String("data", "data", "データディレクトリのパス")
	checkOnly := flag.Bool("check-only", false, "データベースの問題数を確認するのみ")
	flag.Parse()

	// DB接続
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://rikako:password@localhost:5432/rikako?sslmode=disable"
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	// check-onlyモード: データベースの問題数を確認
	if *checkOnly {
		var count int
		err := db.QueryRow("SELECT COUNT(*) FROM questions").Scan(&count)
		if err != nil {
			log.Fatalf("Failed to count questions: %v", err)
		}
		log.Printf("%d", count)
		return
	}

	// インポート実行
	imp := importer.New(db, *dataDir)
	if err := imp.Run(); err != nil {
		log.Fatalf("Import failed: %v", err)
	}

	log.Println("Import completed successfully!")
}
