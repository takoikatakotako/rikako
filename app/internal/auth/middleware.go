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
	"Root":            true,
	"HealthCheck":     true,
	"GetQuestions":    true,
	"GetQuestion":     true,
	"GetCategories":   true,
	"GetCategory":     true,
	"GetWorkbooks":    true,
	"GetWorkbook":     true,
	"SubmitAnswers":    true,
	"GetWrongAnswers":  true,
	"AnonymousSignIn":  true,
	"AnonymousSignOut": true,
}

// NewAuthMiddleware creates a StrictMiddlewareFunc that validates Cognito JWT tokens.
func NewAuthMiddleware(region, userPoolID string) strictecho.StrictEchoMiddlewareFunc {
	provider := NewJWKSProvider(region, userPoolID)
	issuer := fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s", region, userPoolID)

	return newAuthMiddlewareWithProvider(provider, issuer)
}

func newAuthMiddlewareWithProvider(provider *JWKSProvider, issuer string) strictecho.StrictEchoMiddlewareFunc {
	return func(f strictecho.StrictEchoHandlerFunc, operationID string) strictecho.StrictEchoHandlerFunc {
		return func(ctx echo.Context, request interface{}) (interface{}, error) {
			// Skip authentication for public operations
			if publicOperations[operationID] {
				return f(ctx, request)
			}

			// Extract token from Authorization header
			authHeader := ctx.Request().Header.Get("Authorization")
			if authHeader == "" {
				return nil, echo.NewHTTPError(401, "missing authorization header")
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				return nil, echo.NewHTTPError(401, "invalid authorization header format")
			}
			tokenString := parts[1]

			// Parse and validate the JWT
			token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
				// Verify signing method
				if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}

				kid, ok := token.Header["kid"].(string)
				if !ok {
					return nil, fmt.Errorf("missing kid in token header")
				}

				return provider.GetKey(kid)
			}, jwt.WithIssuer(issuer))

			if err != nil || !token.Valid {
				return nil, echo.NewHTTPError(401, "invalid token")
			}

			// Extract user sub and set in context
			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				return nil, echo.NewHTTPError(401, "invalid token claims")
			}

			sub, ok := claims["sub"].(string)
			if !ok {
				return nil, echo.NewHTTPError(401, "missing sub claim")
			}

			// Store user sub in request context
			reqCtx := context.WithValue(ctx.Request().Context(), UserSubContextKey, sub)
			ctx.SetRequest(ctx.Request().WithContext(reqCtx))

			return f(ctx, request)
		}
	}
}
