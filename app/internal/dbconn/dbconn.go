// Package dbconn は DB 接続文字列（DSN）の調整を行う。
package dbconn

import (
	"net/url"
	"strings"
)

// Pooled は usePooler=true のとき、Neon の pooled endpoint（PgBouncer）用に DSN を変換する。
//
//   - host の先頭ラベルに "-pooler" を付与（例: ep-xxx... → ep-xxx-pooler...）。既に付いていれば冪等。
//   - lib/pq は SCRAM channel binding 非対応のため channel_binding パラメータを除去する。
//   - sslmode が未指定なら require を付与する。
//
// これにより、SSM の DATABASE_URL には direct のフル接続文字列（パスワード込み）を
// そのまま置いたまま、環境変数フラグだけで pooled/direct を切り替えられる。
// パスワードには一切触れない。パースできない場合や localhost は変換せずそのまま返す（フェイルセーフ）。
func Pooled(dsn string, usePooler bool) string {
	if !usePooler {
		return dsn
	}
	u, err := url.Parse(dsn)
	if err != nil {
		return dsn
	}
	host := u.Hostname()
	if host == "" || host == "localhost" || host == "127.0.0.1" {
		return dsn
	}

	// host の先頭ラベル（endpoint id）に -pooler を付与（冪等）。
	labels := strings.SplitN(host, ".", 2)
	if !strings.HasSuffix(labels[0], "-pooler") {
		labels[0] += "-pooler"
	}
	newHost := strings.Join(labels, ".")
	if p := u.Port(); p != "" {
		u.Host = newHost + ":" + p
	} else {
		u.Host = newHost
	}

	// lib/pq 非対応の channel_binding を除去、sslmode を担保。
	q := u.Query()
	q.Del("channel_binding")
	if q.Get("sslmode") == "" {
		q.Set("sslmode", "require")
	}
	u.RawQuery = q.Encode()

	return u.String()
}
