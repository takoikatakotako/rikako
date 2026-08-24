# =============================================================================
# API Gateway HTTP API
# =============================================================================

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = var.cors_allow_methods
    allow_headers = var.cors_allow_headers
    max_age       = 86400
  }

  tags = var.tags
}

# =============================================================================
# Lambda Integration
# =============================================================================

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# 実在するパスを明示ルートとして定義する。**`$default` は意図的に残しており、
# この時点でリクエストの処理は何も変わらない**（すべて Lambda に届く）。
#
# 当初は `$default` を外して未定義パスを Lambda まで通さないつもりだったが、
# 実測の結果それはやめた。`$default` を外すと未定義パスはアクセスログにも
# メトリクス（Count / 4xx）にも出ず、**完全に不可視**になる。2026-08-21 の
# スキャン（1分540リクエスト）に気づけたのは、当時の同時実行上限 10 で
# スロットリング → 5xx アラームが鳴ったからで、上限が 1000 になった今（#328）は
# そもそも実害も小さい。無駄な起動を削る利益より、観測を失う損失が大きい。
#
# 明示ルートを置く意味は、アクセスログの `$context.routeKey` が「実在ルート名」か
# `$default` かで分かれること。正常な通信と未定義パスへのアクセスを機械的に
# 区別できるようになり、将来 `$default` の件数にアラームを張る場合の土台になる。
#
# 先頭セグメント単位の許可リストなので、`/users/me/xxx` のような既存セグメント配下の
# エンドポイント追加ではここを触る必要はない。新しい先頭セグメントを足すときだけ
# ルートを追加する。追加漏れは scripts/check-api-routes.py が CI で検出するが、
# **漏れても `$default` が受けるので 404 にはならない**（集計上スキャン側に混ざるだけ）。
locals {
  # openapi.yaml の先頭セグメントと対応。深い階層を持つものは {proxy+} で束ねる。
  route_keys = [
    "ANY /",
    "ANY /health",
    "ANY /status",
    "ANY /answers",
    "ANY /contact",
    "ANY /announcements",
    "ANY /announcements/{proxy+}",
    "ANY /questions",
    "ANY /questions/{proxy+}",
    "ANY /categories",
    "ANY /categories/{proxy+}",
    "ANY /workbooks",
    "ANY /workbooks/{proxy+}",
    "ANY /apps/{proxy+}",
    "ANY /auth/{proxy+}",
    "ANY /users/{proxy+}",
    "ANY /transfer/{proxy+}",
    "ANY /account/{proxy+}",
  ]
}

# 明示ルートに一致しないリクエストの受け皿。これを外すと未定義パスが
# ログにもメトリクスにも出なくなり、スキャンを検知できなくなるため残す。
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each = toset(local.route_keys)

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# =============================================================================
# Access Logs
# =============================================================================
# `/aws/vendedlogs/` プレフィックスにすることで、API Gateway が書き込むための
# CloudWatch Logs リソースポリシー（アカウント上限 5120 文字）を消費しない。
# 記録するのはリクエストのメタデータのみ。Authorization / X-Device-ID / 本文は
# 一切記録しない（機微情報を保存しないため）。

resource "aws_cloudwatch_log_group" "access_logs" {
  name              = "/aws/vendedlogs/apigateway/${var.name}"
  retention_in_days = var.access_log_retention_days
  tags              = var.tags
}

# =============================================================================
# Stage with Throttling
# =============================================================================

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      requestTime             = "$context.requestTime"
      sourceIp                = var.access_log_include_source_ip ? "$context.identity.sourceIp" : "disabled"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      path                    = "$context.path"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLatency         = "$context.responseLatency"
      integrationStatus       = "$context.integration.status"
      integrationErrorMessage = "$context.integrationErrorMessage"
      userAgent               = "$context.identity.userAgent"
    })
  }

  tags = var.tags
}

# =============================================================================
# Lambda Permission
# =============================================================================

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# =============================================================================
# Custom Domain
# =============================================================================

resource "aws_apigatewayv2_domain_name" "this" {
  domain_name = var.custom_domain_name

  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

resource "aws_apigatewayv2_api_mapping" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this.id
  stage       = aws_apigatewayv2_stage.default.id
}
