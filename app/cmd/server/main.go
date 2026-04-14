package main

import (
	"database/sql"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	_ "github.com/lib/pq"
	"github.com/takoikatakotako/rikako/internal/api"
	"github.com/takoikatakotako/rikako/internal/auth"
	"github.com/takoikatakotako/rikako/internal/handler"
	"github.com/takoikatakotako/rikako/internal/identity"
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
	e.Use(logging.RequestLogger(logger))
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// カスタムエラーハンドラ
	e.HTTPErrorHandler = newHTTPErrorHandler(logger)

	// Identity Provider（匿名認証用）
	cognitoRegion := os.Getenv("COGNITO_REGION")
	cognitoIdentityPoolID := os.Getenv("COGNITO_IDENTITY_POOL_ID")

	var idProvider identity.Provider
	if cognitoRegion != "" && cognitoIdentityPoolID != "" {
		var err error
		idProvider, err = identity.NewCognitoProvider(cognitoRegion, cognitoIdentityPoolID)
		if err != nil {
			logger.Error("failed to create identity provider", "error", err)
			os.Exit(1)
		}
	} else {
		idProvider = &identity.MockProvider{}
		logger.Info("using mock identity provider (COGNITO_IDENTITY_POOL_ID not set)")
	}

	// 認証ミドルウェア
	cognitoUserPoolID := os.Getenv("COGNITO_USER_POOL_ID")

	var middlewares []api.StrictMiddlewareFunc
	if cognitoRegion != "" && cognitoUserPoolID != "" {
		middlewares = append(middlewares, auth.NewAuthMiddleware(cognitoRegion, cognitoUserPoolID))
	}

	// ハンドラー登録
	h := handler.New(db, imageBaseURL, logger, idProvider)
	strictHandler := api.NewStrictHandler(h, middlewares)
	api.RegisterHandlers(e, strictHandler)

	// サーバー起動
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	logger.Info("starting server", "port", port)
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
			case http.StatusUnauthorized:
				errCode = "UNAUTHORIZED"
			case http.StatusNotFound:
				errCode = "NOT_FOUND"
			}
		}

		if code >= 500 {
			logger.Error("unhandled error", "error", err, "status", code)
		}

		c.JSON(code, api.Error{Code: errCode, Message: msg})
	}
}
