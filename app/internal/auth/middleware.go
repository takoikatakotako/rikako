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
// clientID は受け付ける ID token の aud（App Client ID）。
func NewAuthMiddleware(region, userPoolID, clientID string) strictecho.StrictEchoMiddlewareFunc {
	provider := NewJWKSProvider(region, userPoolID)
	issuer := fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s", region, userPoolID)

	return newAuthMiddlewareWithProvider(provider, issuer, clientID)
}

func newAuthMiddlewareWithProvider(provider *JWKSProvider, issuer, clientID string) strictecho.StrictEchoMiddlewareFunc {
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

	// parseSub は Authorization ヘッダを解釈する。
	//   present=false            : ヘッダ無し（匿名）
	//   present=true, err==nil   : 有効なトークン。sub を返す
	//   present=true, err!=nil   : ヘッダはあるが無効（期限切れ・署名不正・issuer不一致・形式不正）
	parseSub := func(authHeader string) (sub string, present bool, err error) {
		if authHeader == "" {
			return "", false, nil
		}
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			return "", true, fmt.Errorf("invalid authorization header format")
		}
		// issuer・署名・期限に加え、audience（= App Client ID）を検証する。
		// このAPIは ID token を受け付ける（Cognito の ID token は aud に App Client ID を持つ）。
		token, perr := jwt.Parse(parts[1], keyFunc, jwt.WithIssuer(issuer), jwt.WithAudience(clientID))
		if perr != nil || !token.Valid {
			return "", true, fmt.Errorf("invalid token")
		}
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			return "", true, fmt.Errorf("invalid token claims")
		}
		// access token（token_use=access, client_id を持つ）ではなく ID token のみ受理する。
		if tu, _ := claims["token_use"].(string); tu != "id" {
			return "", true, fmt.Errorf("unexpected token_use: %v", claims["token_use"])
		}
		s, ok := claims["sub"].(string)
		if !ok || s == "" {
			return "", true, fmt.Errorf("missing sub claim")
		}
		return s, true, nil
	}

	setSub := func(ctx echo.Context, sub string) {
		reqCtx := context.WithValue(ctx.Request().Context(), UserSubContextKey, sub)
		ctx.SetRequest(ctx.Request().WithContext(reqCtx))
	}

	return func(f strictecho.StrictEchoHandlerFunc, operationID string) strictecho.StrictEchoHandlerFunc {
		return func(ctx echo.Context, request interface{}) (interface{}, error) {
			sub, present, err := parseSub(ctx.Request().Header.Get("Authorization"))

			if publicOperations[operationID] {
				// ヘッダ無しは匿名で許可。ただしヘッダがあって無効なら 401（期限切れトークンで
				// 静かに匿名フォールバックし、書き込み先が account→device に切り替わるのを防ぐ）。
				if !present {
					return f(ctx, request)
				}
				if err != nil {
					return nil, echo.NewHTTPError(401, "invalid token")
				}
				setSub(ctx, sub)
				return f(ctx, request)
			}

			// 認証必須オペレーション。
			if !present || err != nil {
				return nil, echo.NewHTTPError(401, "invalid or missing token")
			}
			setSub(ctx, sub)
			return f(ctx, request)
		}
	}
}
