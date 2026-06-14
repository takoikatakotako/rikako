package logging

import (
	"encoding/json"
	"os"
	"time"
)

// chatRoutePath は OpenAI API を同期的に呼び出すため遅延が大きく、
// 公開 API の p99 レイテンシメトリクスから除外するルートパターン。
const chatRoutePath = "/questions/:questionId/chat"

// metricNamespace / latencyMetricName は CloudWatch EMF で生成するカスタム
// メトリクスの名前空間・メトリクス名。p99 レイテンシアラームから参照する。
const (
	metricNamespace   = "Rikako/PublicAPI"
	latencyMetricName = "RequestLatency"
)

type emfMetricDefinition struct {
	Name string `json:"Name"`
	Unit string `json:"Unit"`
}

type emfDirective struct {
	Namespace  string                `json:"Namespace"`
	Dimensions [][]string            `json:"Dimensions"`
	Metrics    []emfMetricDefinition `json:"Metrics"`
}

type emfMetadata struct {
	Timestamp         int64          `json:"Timestamp"`
	CloudWatchMetrics []emfDirective `json:"CloudWatchMetrics"`
}

// emitLatencyMetric はリクエストのレイテンシを CloudWatch EMF 形式で stdout に
// 出力する。Lambda 実行環境（AWS_LAMBDA_FUNCTION_NAME 設定時）でのみ出力し、
// チャットルートは遅延が想定内のため除外する。
func emitLatencyMetric(routePath string, latency time.Duration) {
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		return
	}
	if routePath == chatRoutePath {
		return
	}

	doc := map[string]any{
		"_aws": emfMetadata{
			Timestamp: time.Now().UnixMilli(),
			CloudWatchMetrics: []emfDirective{{
				Namespace:  metricNamespace,
				Dimensions: [][]string{{"Service"}},
				Metrics:    []emfMetricDefinition{{Name: latencyMetricName, Unit: "Milliseconds"}},
			}},
		},
		"Service":         "public-api",
		latencyMetricName: float64(latency.Microseconds()) / 1000.0,
	}

	b, err := json.Marshal(doc)
	if err != nil {
		return
	}
	os.Stdout.Write(append(b, '\n'))
}
