package main

import (
	"database/sql"
	"flag"
	"log"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/importer"
)

func main() {
	dataDir := flag.String("data", "data", "データディレクトリのパス")
	checkOnly := flag.Bool("check-only", false, "データベースの問題数を確認するのみ")
	workbooksOnly := flag.Bool("workbooks-only", false, "workbooks/categoriesのみインポート（問題は既存のものを使用）")
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

	// Neon のコネクションプロキシがアイドル接続をリセットするため短めに設定
	db.SetMaxOpenConns(1)
	db.SetConnMaxLifetime(30 * time.Second)
	db.SetConnMaxIdleTime(10 * time.Second)

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
	var importErr error
	if *workbooksOnly {
		importErr = imp.RunWorkbooksOnly()
	} else {
		importErr = imp.Run()
	}
	if importErr != nil {
		log.Fatalf("Import failed: %v", importErr)
	}

	log.Println("Import completed successfully!")
}
