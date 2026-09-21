// Package userpool は Cognito User Pool のユーザー操作（現状は削除のみ）を抽象化する。
// 認証（JWT 検証）は internal/auth、匿名 identity は internal/identity が担当し、
// ここはアカウント削除（#408）でサーバー側から User Pool のユーザーを消すためにある。
package userpool

import (
	"context"
	"errors"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider"
	"github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider/types"
)

// Deleter は sub で指定したユーザーを User Pool から削除する。
// ユーザーが既に存在しない場合はエラーにしない（削除は冪等に扱う）。
type Deleter interface {
	DeleteUserBySub(ctx context.Context, sub string) error
}

// CognitoDeleter は Cognito User Pool に対する実装。
// User Pool のユーザー名は sub と一致しない（メールアドレス等）ため、ListUsers で
// sub から Username を引いてから AdminDeleteUser する。
type CognitoDeleter struct {
	client     *cognitoidentityprovider.Client
	userPoolID string
}

func NewCognitoDeleter(region, userPoolID string) (*CognitoDeleter, error) {
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}
	return &CognitoDeleter{client: cognitoidentityprovider.NewFromConfig(cfg), userPoolID: userPoolID}, nil
}

func (d *CognitoDeleter) DeleteUserBySub(ctx context.Context, sub string) error {
	// sub は Cognito 側で一意。Filter は "sub = \"...\"" の形式。
	out, err := d.client.ListUsers(ctx, &cognitoidentityprovider.ListUsersInput{
		UserPoolId: aws.String(d.userPoolID),
		Filter:     aws.String(fmt.Sprintf("sub = %q", sub)),
		Limit:      aws.Int32(1),
	})
	if err != nil {
		return fmt.Errorf("list users by sub: %w", err)
	}
	if len(out.Users) == 0 {
		return nil // 既に無い（前回の削除で Cognito 側だけ成功していた等）
	}
	_, err = d.client.AdminDeleteUser(ctx, &cognitoidentityprovider.AdminDeleteUserInput{
		UserPoolId: aws.String(d.userPoolID),
		Username:   out.Users[0].Username,
	})
	var notFound *types.UserNotFoundException
	if errors.As(err, &notFound) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("admin delete user: %w", err)
	}
	return nil
}

// NoopDeleter はローカル開発・CI 用（COGNITO_USER_POOL_ID 未設定時）。削除した sub を記録する。
type NoopDeleter struct {
	Deleted []string
}

func (d *NoopDeleter) DeleteUserBySub(_ context.Context, sub string) error {
	d.Deleted = append(d.Deleted, sub)
	return nil
}
