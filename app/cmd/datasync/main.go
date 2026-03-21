package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/datasync"
)

const (
	localDSN       = "postgres://rikako:password@localhost:5432/rikako?sslmode=disable"
	devSSMParam    = "/rikako/dev/database-url"
	devAWSProfile  = "rikako-development-sso"
)

func main() {
	dataDir := flag.String("data", "data", "データディレクトリのパス")
	env := flag.String("env", "local", "接続先環境 (local, dev)")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: datasync [flags] <plan|apply>

Subcommands:
  plan    YAMLとDBの差分を表示する
  apply   YAMLの内容をDBに反映する

Environments:
  local   ローカルPostgreSQL (localhost:5432)
  dev     Neon dev環境 (SSMからURL取得、要: aws sso login --profile %s)

DATABASE_URL環境変数が設定されている場合は--envより優先されます。

Flags:
`, devAWSProfile)
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

	// DB接続URL解決
	dsn, err := resolveDSN(*env)
	if err != nil {
		log.Fatalf("Failed to resolve database URL: %v", err)
	}

	// 接続先を表示
	displayDSN := dsn
	if len(displayDSN) > 60 {
		displayDSN = displayDSN[:60] + "..."
	}
	fmt.Printf("Connecting to [%s]: %s\n", *env, displayDSN)

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

func resolveDSN(env string) (string, error) {
	// DATABASE_URL が設定されていればそれを優先
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		return dsn, nil
	}

	switch env {
	case "local":
		return localDSN, nil
	case "dev":
		return fetchDSNFromSSM(devAWSProfile, devSSMParam)
	default:
		return "", fmt.Errorf("unknown environment: %s", env)
	}
}

func fetchDSNFromSSM(profile, paramName string) (string, error) {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithSharedConfigProfile(profile),
	)
	if err != nil {
		return "", fmt.Errorf("AWS config load failed (profile: %s): %w\nRun: aws sso login --profile %s", profile, err, profile)
	}

	client := ssm.NewFromConfig(cfg)
	out, err := client.GetParameter(ctx, &ssm.GetParameterInput{
		Name:           &paramName,
		WithDecryption: boolPtr(true),
	})
	if err != nil {
		return "", fmt.Errorf("SSM GetParameter failed (%s): %w\nRun: aws sso login --profile %s", paramName, err, profile)
	}

	return *out.Parameter.Value, nil
}

func boolPtr(b bool) *bool {
	return &b
}
