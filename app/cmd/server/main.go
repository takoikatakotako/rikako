package main

import (
	"database/sql"
	"log"
	"os"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/handler"
)

func main() {
	// DB接続
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://rikako:password@localhost:5432/rikako?sslmode=disable"
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("failed to ping database: %v", err)
	}

	// DB接続プーリング設定（Lambda最適化）
	db.SetMaxOpenConns(10)                  // 最大接続数
	db.SetMaxIdleConns(2)                   // アイドル接続数
	db.SetConnMaxLifetime(5 * time.Minute)  // 接続の最大ライフタイム
	db.SetConnMaxIdleTime(1 * time.Minute)  // アイドル接続の最大時間

	// 画像のベースURL
	imageBaseURL := os.Getenv("IMAGE_BASE_URL")
	if imageBaseURL == "" {
		imageBaseURL = "https://example.com"
	}

	// Echo初期化
	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// ハンドラー登録
	h := handler.New(db, imageBaseURL)
	strictHandler := api.NewStrictHandler(h, nil)
	api.RegisterHandlers(e, strictHandler)

	// サーバー起動
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting server on :%s", port)
	if err := e.Start(":" + port); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
