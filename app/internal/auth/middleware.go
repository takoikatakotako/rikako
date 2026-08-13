package auth

import (
	"context"
	"fmt"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
	strictecho "github.com/oapi-codegen/runtime/strictmiddleware/echo"
)

type contextKey string

const UserSubContextKey contextKey = "user_sub"

// publicOperations are operations that do not require authentication.
var publicOperations = map[string]bool{
	"Root":                true,
	"HealthCheck":         true,
	"GetAppStatus":        true,
	"GetQuestions":        true,
	"GetQuestion":         true,
	"GetApp":              true,
	"GetCategories":       true,
	"GetCategory":         true,
	"GetWorkbooks":        true,
	"GetWorkbook":         true,
	"GetAnnouncements":    true,
	"GetAnnouncement":     true,
	"SubmitAnswers":       true,
	"GetWrongAnswers":     true,
	"GetAnswerLogs":       true,
	"GetWorkbookProgress": true,
	"GetUserSummary":      true,
	"AnonymousSignIn":     true,
	"AnonymousSignOut":    true,
	"GetUserProfile":      true,
	"UpdateUserProfile":   true,
	"SubmitContact":       true,
	"GetTransferToken":    true,
	"IssueTransferToken":  true,
	"ApplyTransferToken":  true,
	"ChatWithQuestion":    true,
}

// NewAuthMiddleware creates a StrictMiddlewareFunc that validates Cognito JWT tokens.
func NewAuthMiddleware(region, userPoolID string) strictecho.StrictEchoMiddlewareFunc {
	provider := NewJWKSProvider(region, userPoolID)
	issuer := fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s", region, userPoolID)

	return newAuthMiddlewareWithProvider(provider, issuer)
}

func newAuthMiddlewareWithProvider(provider *JWKSProvider, issuer string) strictecho.StrictEchoMiddlewareFunc {
	keyFunc := func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		kid, ok := token.Header["kid"].(string)
		if !ok {
			return nil, fmt.Errorf("missing kid in token header")
		}
		return provider.GetKey(kid)
	}

	// validateSub は Authorization ヘッダの Bearer トークンを検証し sub を返す。
	// 検証できなければ ok=false（エラーは返さない）。
	validateSub := func(authHeader string) (string, bool) {
		if authHeader == "" {
			return "", false
		}
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			return "", false
		}
		token, err := jwt.Parse(parts[1], keyFunc, jwt.WithIssuer(issuer))
		if err != nil || !token.Valid {
			return "", false
		}
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			return "", false
		}
		sub, ok := claims["sub"].(string)
		if !ok || sub == "" {
			return "", false
		}
		return sub, true
	}

	setSub := func(ctx echo.Context, sub string) {
		reqCtx := context.WithValue(ctx.Request().Context(), UserSubContextKey, sub)
		ctx.SetRequest(ctx.Request().WithContext(reqCtx))
	}

	return func(f strictecho.StrictEchoHandlerFunc, operationID string) strictecho.StrictEchoHandlerFunc {
		return func(ctx echo.Context, request interface{}) (interface{}, error) {
			sub, ok := validateSub(ctx.Request().Header.Get("Authorization"))

			// 公開オペレーションは best-effort 認証: 有効なトークンがあれば sub を積む
			// （無ければ従来どおり匿名 X-Device-ID で解決される）。
			if publicOperations[operationID] {
				if ok {
					setSub(ctx, sub)
				}
				return f(ctx, request)
			}

			// 認証必須オペレーション。
			if !ok {
				return nil, echo.NewHTTPError(401, "invalid or missing token")
			}
			setSub(ctx, sub)
			return f(ctx, request)
		}
	}
}
