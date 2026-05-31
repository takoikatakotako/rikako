package secrets

import (
	"context"
	"errors"
	"os"
	"reflect"
	"sort"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	ssmtypes "github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

type fakeFetcher struct {
	params  map[string]string
	invalid []string
	err     error
	calls   int
}

func (f *fakeFetcher) GetParameters(ctx context.Context, in *ssm.GetParametersInput, _ ...func(*ssm.Options)) (*ssm.GetParametersOutput, error) {
	f.calls++
	if f.err != nil {
		return nil, f.err
	}
	out := &ssm.GetParametersOutput{}
	for _, name := range in.Names {
		if v, ok := f.params[name]; ok {
			n := name
			val := v
			out.Parameters = append(out.Parameters, ssmtypes.Parameter{Name: &n, Value: &val})
			continue
		}
		out.InvalidParameters = append(out.InvalidParameters, name)
	}
	if len(f.invalid) > 0 {
		out.InvalidParameters = append(out.InvalidParameters, f.invalid...)
	}
	return out, nil
}

func TestCollectSSMRefs(t *testing.T) {
	tests := []struct {
		name    string
		env     []string
		want    map[string]string
		wantErr bool
	}{
		{
			name: "no ssm references",
			env:  []string{"FOO=bar", "BAZ=qux"},
			want: map[string]string{},
		},
		{
			name: "single reference",
			env:  []string{"FOO=ssm:/a/b/c"},
			want: map[string]string{"FOO": "/a/b/c"},
		},
		{
			name: "mixed references",
			env:  []string{"FOO=ssm:/a/b", "BAR=plain", "BAZ=ssm:/c/d"},
			want: map[string]string{"FOO": "/a/b", "BAZ": "/c/d"},
		},
		{
			name:    "missing leading slash",
			env:     []string{"FOO=ssm:bad"},
			wantErr: true,
		},
		{
			name: "ignores entries without '='",
			env:  []string{"FOO=ssm:/x", "BROKEN"},
			want: map[string]string{"FOO": "/x"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := collectSSMRefs(tt.env)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestChunk(t *testing.T) {
	got := chunk([]string{"a", "b", "c", "d", "e"}, 2)
	want := [][]string{{"a", "b"}, {"c", "d"}, {"e"}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	if chunk([]string{"a"}, 0) != nil {
		t.Fatalf("expected nil for non-positive size")
	}
}

func TestUniquePaths(t *testing.T) {
	got := uniquePaths(map[string]string{"A": "/x", "B": "/x", "C": "/y"})
	sort.Strings(got)
	want := []string{"/x", "/y"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestResolveWith_NoRefs(t *testing.T) {
	t.Setenv("FOO", "plain")
	f := &fakeFetcher{}
	if err := ResolveWith(context.Background(), f); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.calls != 0 {
		t.Fatalf("fetcher should not be called when no ssm refs, got %d", f.calls)
	}
}

func TestResolveWith_Single(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "ssm:/rikako/dev/openai")
	f := &fakeFetcher{params: map[string]string{"/rikako/dev/openai": "sk-real-value"}}
	if err := ResolveWith(context.Background(), f); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got := os.Getenv("OPENAI_API_KEY"); got != "sk-real-value" {
		t.Fatalf("got %q, want %q", got, "sk-real-value")
	}
	if f.calls != 1 {
		t.Fatalf("expected 1 fetch call, got %d", f.calls)
	}
}

func TestResolveWith_DuplicatePath(t *testing.T) {
	t.Setenv("A", "ssm:/shared")
	t.Setenv("B", "ssm:/shared")
	f := &fakeFetcher{params: map[string]string{"/shared": "v"}}
	if err := ResolveWith(context.Background(), f); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if os.Getenv("A") != "v" || os.Getenv("B") != "v" {
		t.Fatalf("A=%q B=%q", os.Getenv("A"), os.Getenv("B"))
	}
	if f.calls != 1 {
		t.Fatalf("expected 1 fetch call (deduped), got %d", f.calls)
	}
}

func TestResolveWith_BatchOverTen(t *testing.T) {
	want := map[string]string{}
	for i := 0; i < 11; i++ {
		envKey := "K" + string(rune('A'+i))
		path := "/p/" + string(rune('a'+i))
		t.Setenv(envKey, "ssm:"+path)
		want[path] = "val-" + string(rune('a'+i))
	}
	f := &fakeFetcher{params: want}
	if err := ResolveWith(context.Background(), f); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.calls != 2 {
		t.Fatalf("expected 2 batch calls for 11 items, got %d", f.calls)
	}
}

func TestResolveWith_InvalidParameter(t *testing.T) {
	t.Setenv("FOO", "ssm:/missing")
	f := &fakeFetcher{params: map[string]string{}}
	err := ResolveWith(context.Background(), f)
	if err == nil || !strings.Contains(err.Error(), "invalid parameters") {
		t.Fatalf("expected invalid parameters error, got %v", err)
	}
}

func TestResolveWith_FetchError(t *testing.T) {
	t.Setenv("FOO", "ssm:/x")
	sentinel := errors.New("boom")
	f := &fakeFetcher{err: sentinel}
	err := ResolveWith(context.Background(), f)
	if err == nil || !errors.Is(err, sentinel) {
		t.Fatalf("expected wrapped sentinel error, got %v", err)
	}
}

func TestResolveWith_InvalidPrefix(t *testing.T) {
	t.Setenv("FOO", "ssm:no-leading-slash")
	f := &fakeFetcher{}
	err := ResolveWith(context.Background(), f)
	if err == nil {
		t.Fatalf("expected error for invalid prefix, got nil")
	}
	if f.calls != 0 {
		t.Fatalf("fetcher should not be called on parse error, got %d", f.calls)
	}
}

// suppress unused import warnings if aws helper isn't used elsewhere in tests
var _ = aws.Bool
