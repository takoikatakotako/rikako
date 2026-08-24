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

# 実在するパスだけを Lambda へ通す。
#
# **ロールアウト第1段階**: いまは `$default` を残したまま明示ルートを追加している。
# 明示ルートは `$default` より優先されるので、既存の通信を維持したまま到達確認できる。
# dev で実在パスの疎通を確認したあと、別 PR で `$default` だけを削除する（第2段階）。
# 一度に入れ替えると、`$default` の削除が先に走った場合に正常なパスまで 404 になる
# （独立リソースなので Terraform は順序を保証しない）。
#
# 以前は `$default` の catch-all だったため、`/.env` や `/.aws/credentials` の
# ような存在しないパスでも Lambda が起動していた。2026-08-21 のスキャンでは
# 1分間に 318 回の無駄な起動が発生し、同時実行枠を食って 220 件が
# スロットリング → API Gateway が 5xx を返した（#327）。
#
# 先頭セグメント単位の許可リストにしてあるので、`/users/me/xxx` のような
# 既存セグメント配下のエンドポイント追加では、ここを触る必要はない。
# 変更が要るのは新しい先頭セグメントを足すときだけ。
#
# 未定義パスは Lambda まで届かず、API Gateway が 404 を返す
# （レスポンス本文はアプリの 404 JSON ではなく {"message":"Not Found"}）。
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

# 第2段階でこのリソースを削除する。それまでは明示ルートのフォールバックとして残す。
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
