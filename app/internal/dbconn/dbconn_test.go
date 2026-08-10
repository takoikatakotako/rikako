package dbconn

import (
	"net/url"
	"strings"
	"testing"
)

func TestPooled_disabled(t *testing.T) {
	dsn := "postgres://role:pass@ep-abc.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
	if got := Pooled(dsn, false); got != dsn {
		t.Errorf("usePooler=false は変換しない。want %s, got %s", dsn, got)
	}
}

func TestPooled_addsPoolerAndFixesParams(t *testing.T) {
	dsn := "postgres://role:pass@ep-abc.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
	got := Pooled(dsn, true)

	u, err := url.Parse(got)
	if err != nil {
		t.Fatalf("結果がパースできない: %v", err)
	}
	if u.Hostname() != "ep-abc-pooler.ap-southeast-1.aws.neon.tech" {
		t.Errorf("host に -pooler が付いていない: %s", u.Hostname())
	}
	if u.Query().Get("channel_binding") != "" {
		t.Errorf("channel_binding が除去されていない: %s", got)
	}
	if u.Query().Get("sslmode") != "require" {
		t.Errorf("sslmode=require が維持されていない: %s", got)
	}
	// パスワードが保持されている。
	if pw, _ := u.User.Password(); pw != "pass" {
		t.Errorf("パスワードが保持されていない: %q", pw)
	}
}

func TestPooled_idempotent(t *testing.T) {
	dsn := "postgres://role:pass@ep-abc-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
	got := Pooled(dsn, true)
	u, _ := url.Parse(got)
	if strings.Count(u.Hostname(), "-pooler") != 1 {
		t.Errorf("-pooler が二重付与された: %s", u.Hostname())
	}
}

func TestPooled_addsSslmodeWhenMissing(t *testing.T) {
	dsn := "postgres://role:pass@ep-abc.ap-southeast-1.aws.neon.tech/neondb"
	got := Pooled(dsn, true)
	u, _ := url.Parse(got)
	if u.Query().Get("sslmode") != "require" {
		t.Errorf("sslmode が補われていない: %s", got)
	}
}

func TestPooled_localhostUnchanged(t *testing.T) {
	dsn := "postgres://rikako:password@localhost:5432/rikako?sslmode=disable"
	if got := Pooled(dsn, true); got != dsn {
		t.Errorf("localhost は変換しない。got %s", got)
	}
}
