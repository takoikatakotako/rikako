package logging

import (
	"log/slog"
	"time"

	"github.com/labstack/echo/v4"
)

// RequestLogger returns an Echo middleware that logs requests using slog in JSON format.
func RequestLogger(logger *slog.Logger) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			start := time.Now()

			err := next(c)
			if err != nil {
				c.Error(err)
			}

			latency := time.Since(start)
			req := c.Request()
			status := c.Response().Status

			attrs := []slog.Attr{
				slog.String("method", req.Method),
				slog.String("path", req.URL.Path),
				slog.Int("status", status),
				slog.String("latency", latency.String()),
				slog.String("remote_ip", c.RealIP()),
			}

			if query := req.URL.RawQuery; query != "" {
				attrs = append(attrs, slog.String("query", query))
			}

			if status >= 500 {
				logger.LogAttrs(req.Context(), slog.LevelError, "request", attrs...)
			} else if status >= 400 {
				logger.LogAttrs(req.Context(), slog.LevelWarn, "request", attrs...)
			} else {
				logger.LogAttrs(req.Context(), slog.LevelInfo, "request", attrs...)
			}

			return nil
		}
	}
}
