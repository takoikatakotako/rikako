package auth

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
	strictecho "github.com/oapi-codegen/runtime/strictmiddleware/echo"
)

const testKid = "test-kid-1"

func setupTestJWKS(t *testing.T) (*rsa.PrivateKey, *httptest.Server) {
	t.Helper()

	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("failed to generate RSA key: %v", err)
	}

	jwksServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		pubKey := &privateKey.PublicKey
		resp := jwksResponse{
			Keys: []jwk{
				{
					Kid: testKid,
					Kty: "RSA",
					Alg: "RS256",
					Use: "sig",
					N:   base64.RawURLEncoding.EncodeToString(pubKey.N.Bytes()),
					E:   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(pubKey.E)).Bytes()),
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))

	return privateKey, jwksServer
}

func createTestToken(privateKey *rsa.PrivateKey, issuer string, sub string) string {
	claims := jwt.MapClaims{
		"sub": sub,
		"iss": issuer,
		"exp": time.Now().Add(1 * time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = testKid

	tokenString, _ := token.SignedString(privateKey)
	return tokenString
}

func createMiddleware(t *testing.T) (*rsa.PrivateKey, string, strictecho.StrictEchoMiddlewareFunc, *httptest.Server) {
	t.Helper()

	privateKey, jwksServer := setupTestJWKS(t)
	issuer := "https://cognito-idp.ap-northeast-1.amazonaws.com/test-pool"
	provider := newJWKSProviderWithURL(jwksServer.URL)
	mw := newAuthMiddlewareWithProvider(provider, issuer)

	return privateKey, issuer, mw, jwksServer
}

// stubHandler is a simple handler that returns a success string.
func stubHandler(ctx echo.Context, request interface{}) (interface{}, error) {
	return "ok", nil
}

func TestPublicOperationsPassWithoutToken(t *testing.T) {
	_, _, mw, jwksServer := createMiddleware(t)
	defer jwksServer.Close()

	publicOps := []string{
		"Root", "HealthCheck",
		"GetQuestions", "GetQuestion",
		"GetCategories", "GetCategory",
		"GetWorkbooks", "GetWorkbook",
	}
	for _, op := range publicOps {
		t.Run(op, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			rec := httptest.NewRecorder()
			ctx := e.NewContext(req, rec)

			handler := mw(stubHandler, op)
			result, err := handler(ctx, nil)
			if err != nil {
				t.Fatalf("expected no error for public operation %s, got: %v", op, err)
			}
			if result != "ok" {
				t.Fatalf("expected 'ok', got: %v", result)
			}
		})
	}
}

func TestProtectedOperationWithoutToken(t *testing.T) {
	_, _, mw, jwksServer := createMiddleware(t)
	defer jwksServer.Close()

	protectedOps := []string{"SomeProtectedOperation"}
	for _, op := range protectedOps {
		t.Run(op, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/questions", nil)
			rec := httptest.NewRecorder()
			ctx := e.NewContext(req, rec)

			handler := mw(stubHandler, op)
			_, err := handler(ctx, nil)
			if err == nil {
				t.Fatal("expected error for protected operation without token")
			}

			httpErr, ok := err.(*echo.HTTPError)
			if !ok {
				t.Fatalf("expected echo.HTTPError, got: %T", err)
			}
			if httpErr.Code != 401 {
				t.Fatalf("expected 401, got: %d", httpErr.Code)
			}
		})
	}
}

func TestProtectedOperationWithInvalidToken(t *testing.T) {
	_, _, mw, jwksServer := createMiddleware(t)
	defer jwksServer.Close()

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/questions", nil)
	req.Header.Set("Authorization", "Bearer invalid-token")
	rec := httptest.NewRecorder()
	ctx := e.NewContext(req, rec)

	handler := mw(stubHandler, "SomeProtectedOperation")
	_, err := handler(ctx, nil)
	if err == nil {
		t.Fatal("expected error for invalid token")
	}

	httpErr, ok := err.(*echo.HTTPError)
	if !ok {
		t.Fatalf("expected echo.HTTPError, got: %T", err)
	}
	if httpErr.Code != 401 {
		t.Fatalf("expected 401, got: %d", httpErr.Code)
	}
}

func TestProtectedOperationWithValidToken(t *testing.T) {
	privateKey, issuer, mw, jwksServer := createMiddleware(t)
	defer jwksServer.Close()

	token := createTestToken(privateKey, issuer, "test-user-123")

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	ctx := e.NewContext(req, rec)

	handler := mw(stubHandler, "SomeProtectedOperation")
	result, err := handler(ctx, nil)
	if err != nil {
		t.Fatalf("expected no error with valid token, got: %v", err)
	}
	if result != "ok" {
		t.Fatalf("expected 'ok', got: %v", result)
	}

	// Verify user sub was set in context
	sub := ctx.Request().Context().Value(UserSubContextKey)
	if sub != "test-user-123" {
		t.Fatalf("expected sub 'test-user-123', got: %v", sub)
	}
}

func TestProtectedOperationWithWrongIssuer(t *testing.T) {
	privateKey, _, mw, jwksServer := createMiddleware(t)
	defer jwksServer.Close()

	// Create token with wrong issuer
	token := createTestToken(privateKey, "https://wrong-issuer.example.com", "test-user-123")

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	ctx := e.NewContext(req, rec)

	handler := mw(stubHandler, "SomeProtectedOperation")
	_, err := handler(ctx, nil)
	if err == nil {
		t.Fatal("expected error for token with wrong issuer")
	}

	httpErr, ok := err.(*echo.HTTPError)
	if !ok {
		t.Fatalf("expected echo.HTTPError, got: %T", err)
	}
	if httpErr.Code != 401 {
		t.Fatalf("expected 401, got: %d", httpErr.Code)
	}
}

func TestInvalidAuthorizationHeaderFormat(t *testing.T) {
	_, _, mw, jwksServer := createMiddleware(t)
	defer jwksServer.Close()

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/protected", nil)
	req.Header.Set("Authorization", "NotBearer some-token")
	rec := httptest.NewRecorder()
	ctx := e.NewContext(req, rec)

	handler := mw(stubHandler, "SomeProtectedOperation")
	_, err := handler(ctx, nil)
	if err == nil {
		t.Fatal("expected error for invalid auth header format")
	}

	httpErr, ok := err.(*echo.HTTPError)
	if !ok {
		t.Fatalf("expected echo.HTTPError, got: %T", err)
	}
	if httpErr.Code != 401 {
		t.Fatalf("expected 401, got: %d", httpErr.Code)
	}
}
