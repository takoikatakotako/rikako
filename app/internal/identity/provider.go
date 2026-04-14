package identity

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cognitoidentity"
	"github.com/google/uuid"
)

// Provider creates anonymous identity IDs.
type Provider interface {
	GetIdentityID(ctx context.Context) (string, error)
}

// CognitoProvider calls Cognito Identity Pool to create identity IDs.
type CognitoProvider struct {
	client         *cognitoidentity.Client
	identityPoolID string
}

func NewCognitoProvider(region, identityPoolID string) (*CognitoProvider, error) {
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}
	return &CognitoProvider{
		client:         cognitoidentity.NewFromConfig(cfg),
		identityPoolID: identityPoolID,
	}, nil
}

func (p *CognitoProvider) GetIdentityID(ctx context.Context) (string, error) {
	out, err := p.client.GetId(ctx, &cognitoidentity.GetIdInput{
		IdentityPoolId: &p.identityPoolID,
	})
	if err != nil {
		return "", fmt.Errorf("cognito GetId failed: %w", err)
	}
	if out.IdentityId == nil {
		return "", fmt.Errorf("cognito GetId returned nil IdentityId")
	}
	return *out.IdentityId, nil
}

// MockProvider generates local UUIDs for development without Cognito.
type MockProvider struct{}

func (p *MockProvider) GetIdentityID(_ context.Context) (string, error) {
	return "local:" + uuid.NewString(), nil
}
