package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/datasync"
)

func main() {
	dataDir := flag.String("data", "data", "データディレクトリのパス")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: datasync [flags] <plan|apply>\n\nSubcommands:\n  plan    YAMLとDBの差分を表示する\n  apply   YAMLの内容をDBに反映する\n\nFlags:\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	if flag.NArg() < 1 {
		flag.Usage()
		os.Exit(1)
	}

	command := flag.Arg(0)
	if command != "plan" && command != "apply" {
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", command)
		flag.Usage()
		os.Exit(1)
	}

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

	syncer := datasync.New(db, *dataDir)

	switch command {
	case "plan":
		plan, err := syncer.Plan()
		if err != nil {
			log.Fatalf("Plan failed: %v", err)
		}
		datasync.PrintPlan(plan)
		if !plan.HasChanges() {
			fmt.Println("\nNo changes. YAML and DB are in sync.")
		}

	case "apply":
		plan, err := syncer.Apply()
		if err != nil {
			log.Fatalf("Apply failed: %v", err)
		}
		datasync.PrintPlan(plan)
		if plan.HasChanges() {
			fmt.Println("\nApply complete!")
		} else {
			fmt.Println("\nNo changes. YAML and DB are already in sync.")
		}
	}
}
