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

// Deleter は User Pool のユーザーを削除する。
// ユーザーが既に存在しない場合はエラーにしない（削除は冪等に扱う）。
type Deleter interface {
	// DeleteUser は User Pool 上のユーザー名（ID token の cognito:username）で削除する。
	// sub からの ListUsers 検索は結果整合で取りこぼしうるため使わない。
	DeleteUser(ctx context.Context, username string) error
}

// CognitoDeleter は Cognito User Pool に対する実装（AdminDeleteUser）。
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

func (d *CognitoDeleter) DeleteUser(ctx context.Context, username string) error {
	if username == "" {
		return errors.New("username is empty")
	}
	_, err := d.client.AdminDeleteUser(ctx, &cognitoidentityprovider.AdminDeleteUserInput{
		UserPoolId: aws.String(d.userPoolID),
		Username:   aws.String(username),
	})
	var notFound *types.UserNotFoundException
	if errors.As(err, &notFound) {
		return nil // 既に無い（前回の削除で Cognito 側だけ成功していた等）
	}
	if err != nil {
		return fmt.Errorf("admin delete user: %w", err)
	}
	return nil
}

// NoopDeleter はローカル開発・CI 用（COGNITO_USER_POOL_ID 未設定時）。削除したユーザー名を記録する。
type NoopDeleter struct {
	Deleted []string
}

func (d *NoopDeleter) DeleteUser(_ context.Context, username string) error {
	d.Deleted = append(d.Deleted, username)
	return nil
}
