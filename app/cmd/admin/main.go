package main

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/admin"
	"github.com/takoikatakotako/rikako/internal/adminapi"
	"github.com/takoikatakotako/rikako/internal/logging"
)

func main() {
	logger := logging.NewLogger()

	// DB接続
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://rikako:password@localhost:5432/rikako?sslmode=disable"
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		logger.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		logger.Error("failed to ping database", "error", err)
		os.Exit(1)
	}

	// DB接続プーリング設定（Lambda最適化）
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(2)
	db.SetConnMaxLifetime(5 * time.Minute)
	db.SetConnMaxIdleTime(1 * time.Minute)

	// 画像のベースURL
	imageBaseURL := os.Getenv("IMAGE_BASE_URL")
	if imageBaseURL == "" {
		imageBaseURL = "https://example.com"
	}

	// S3クライアント初期化（オプション）
	var s3Client *s3.Client
	s3Bucket := os.Getenv("IMAGE_S3_BUCKET")
	if s3Bucket != "" {
		cfg, err := config.LoadDefaultConfig(context.Background())
		if err != nil {
			logger.Error("failed to load AWS config", "error", err)
			os.Exit(1)
		}
		s3Client = s3.NewFromConfig(cfg)
	}

	// Echo初期化
	e := echo.New()
	e.Use(logging.RequestLogger(logger))
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// カスタムエラーハンドラ
	e.HTTPErrorHandler = newHTTPErrorHandler(logger)

	// ハンドラー登録（認証なし）
	h := admin.New(db, imageBaseURL, s3Client, s3Bucket, logger)
	strictHandler := adminapi.NewStrictHandler(h, nil)
	adminapi.RegisterHandlers(e, strictHandler)

	// サーバー起動
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	logger.Info("starting admin server", "port", port)
	if err := e.Start(":" + port); err != nil {
		logger.Error("failed to start server", "error", err)
		os.Exit(1)
	}
}

func newHTTPErrorHandler(logger *slog.Logger) func(err error, c echo.Context) {
	return func(err error, c echo.Context) {
		if c.Response().Committed {
			return
		}

		code := http.StatusInternalServerError
		errCode := "INTERNAL_ERROR"
		msg := "internal server error"

		var he *echo.HTTPError
		if errors.As(err, &he) {
			code = he.Code
			if m, ok := he.Message.(string); ok {
				msg = m
			}
			switch code {
			case http.StatusBadRequest:
				errCode = "INVALID_PARAMETER"
			case http.StatusNotFound:
				errCode = "NOT_FOUND"
			}
		}

		if code >= 500 {
			logger.Error("unhandled error", "error", err, "status", code)
		}

		c.JSON(code, adminapi.Error{Code: errCode, Message: msg})
	}
}
