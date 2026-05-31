// Package secrets は環境変数中の SSM Parameter Store 参照を起動時に解決する。
//
// Lambda 環境変数に値そのものを書くと aws lambda update-function-code の
// レスポンス JSON 経由でログに露出するため、値の代わりに "ssm:/path" 形式の
// 参照を入れておき、起動時に実値を SSM から取得して os.Setenv で展開する。
package secrets

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
)

const ssmPrefix = "ssm:"

const batchSize = 10

// ParameterFetcher は ssm.Client.GetParameters のテスト用抽象。
type ParameterFetcher interface {
	GetParameters(ctx context.Context, params *ssm.GetParametersInput, optFns ...func(*ssm.Options)) (*ssm.GetParametersOutput, error)
}

// Resolve は os.Environ() を走査し、値が "ssm:" プレフィックス付きの環境変数を
// SSM Parameter Store から取得した実値で上書きする。
func Resolve(ctx context.Context) error {
	refs, err := collectSSMRefs(os.Environ())
	if err != nil {
		return err
	}
	if len(refs) == 0 {
		return nil
	}

	cfg, err := awsconfig.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("aws config load: %w", err)
	}
	return ResolveWith(ctx, ssm.NewFromConfig(cfg))
}

// ResolveWith は Resolve と同じ処理を、注入された fetcher を用いて行う。
// 主にテスト用。
func ResolveWith(ctx context.Context, fetcher ParameterFetcher) error {
	refs, err := collectSSMRefs(os.Environ())
	if err != nil {
		return err
	}
	if len(refs) == 0 {
		return nil
	}

	pathToValue, err := fetchAll(ctx, fetcher, uniquePaths(refs))
	if err != nil {
		return err
	}

	for envKey, path := range refs {
		v, ok := pathToValue[path]
		if !ok {
			return fmt.Errorf("ssm: resolved value missing for %s (%s)", envKey, path)
		}
		if err := os.Setenv(envKey, v); err != nil {
			return fmt.Errorf("ssm: setenv %s: %w", envKey, err)
		}
	}
	return nil
}

// collectSSMRefs は os.Environ() 形式の "KEY=VALUE" スライスを走査し、
// 値が ssm: プレフィックス付きの環境変数を envKey -> ssmPath で返す。
func collectSSMRefs(env []string) (map[string]string, error) {
	refs := map[string]string{}
	for _, kv := range env {
		i := strings.IndexByte(kv, '=')
		if i < 0 {
			continue
		}
		key, val := kv[:i], kv[i+1:]
		if !strings.HasPrefix(val, ssmPrefix) {
			continue
		}
		path := strings.TrimPrefix(val, ssmPrefix)
		if !strings.HasPrefix(path, "/") {
			return nil, fmt.Errorf("ssm: invalid reference for %s: path must start with '/' (got %q)", key, path)
		}
		refs[key] = path
	}
	return refs, nil
}

func uniquePaths(refs map[string]string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(refs))
	for _, p := range refs {
		if _, ok := seen[p]; ok {
			continue
		}
		seen[p] = struct{}{}
		out = append(out, p)
	}
	return out
}

func chunk(items []string, size int) [][]string {
	if size <= 0 {
		return nil
	}
	out := make([][]string, 0, (len(items)+size-1)/size)
	for i := 0; i < len(items); i += size {
		end := i + size
		if end > len(items) {
			end = len(items)
		}
		out = append(out, items[i:end])
	}
	return out
}

func fetchAll(ctx context.Context, fetcher ParameterFetcher, paths []string) (map[string]string, error) {
	pathToValue := make(map[string]string, len(paths))
	for _, batch := range chunk(paths, batchSize) {
		out, err := fetcher.GetParameters(ctx, &ssm.GetParametersInput{
			Names:          batch,
			WithDecryption: aws.Bool(true),
		})
		if err != nil {
			return nil, fmt.Errorf("ssm: GetParameters: %w", err)
		}
		if len(out.InvalidParameters) > 0 {
			return nil, fmt.Errorf("ssm: invalid parameters: %v", out.InvalidParameters)
		}
		for _, p := range out.Parameters {
			if p.Name != nil && p.Value != nil {
				pathToValue[*p.Name] = *p.Value
			}
		}
	}
	return pathToValue, nil
}
