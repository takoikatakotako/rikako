// Package appslug は X-App-Slug ヘッダをリクエスト context に橋渡しする。
// strict-server のハンドラは echo.Context を受け取らないため、ヘッダを
// context に載せておき context.Context 経由で読めるようにする。
package appslug

import (
	"context"
	"os"
	"strings"

	"github.com/labstack/echo/v4"
)

type contextKey struct{}

// Header はアプリ識別子を運ぶヘッダ名。
const Header = "X-App-Slug"

// Middleware は X-App-Slug をリクエスト context に格納する。未指定なら何もしない。
func Middleware(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		if slug := c.Request().Header.Get(Header); slug != "" {
			ctx := context.WithValue(c.Request().Context(), contextKey{}, slug)
			c.SetRequest(c.Request().WithContext(ctx))
		}
		return next(c)
	}
}

// FromContext は X-App-Slug の値を返す。未指定なら空文字。
func FromContext(ctx context.Context) string {
	slug, _ := ctx.Value(contextKey{}).(string)
	return slug
}

// VersionOverride は slug 別の env 上書き（例: MINIMUM_VERSION_IT_PASSPORT）が
// あればそれを、無ければ defaultVersion を返す。slug のハイフンは大文字＋アンダースコアに正規化する。
// これにより minimumVersion/latestVersion をアプリ（slug）別に設定でき、強制アップデートを
// アプリ単位で独立に制御できる。
func VersionOverride(defaultVersion, envPrefix, slug string) string {
	if slug == "" {
		return defaultVersion
	}
	key := envPrefix + "_" + strings.ToUpper(strings.ReplaceAll(slug, "-", "_"))
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVersion
}
