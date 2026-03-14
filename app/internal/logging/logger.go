package logging

import (
	"log/slog"
	"os"
	"strings"
)

// NewLogger creates a JSON slog.Logger with level configured via LOG_LEVEL env var.
func NewLogger() *slog.Logger {
	level := slog.LevelInfo
	if l := os.Getenv("LOG_LEVEL"); l != "" {
		switch strings.ToUpper(l) {
		case "DEBUG":
			level = slog.LevelDebug
		case "WARN":
			level = slog.LevelWarn
		case "ERROR":
			level = slog.LevelError
		}
	}
	return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level}))
}
