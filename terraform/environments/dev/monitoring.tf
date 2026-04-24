# =============================================================================
# Slack 通知
# =============================================================================
# 事前準備: Slack Incoming Webhook URL を SSM Parameter Store に SecureString で保存
#   aws ssm put-parameter --name /rikako/development/slack-webhook-url \
#     --value 'https://hooks.slack.com/services/...' --type SecureString
# =============================================================================

data "aws_ssm_parameter" "slack_webhook_url" {
  name            = "/${local.project}/${local.environment}/slack-webhook-url"
  with_decryption = true
}

resource "aws_sns_topic" "alerts" {
  name = "${local.project}-alerts-${local.environment}"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# --- Slack 通知 Lambda ---

data "archive_file" "slack_notifier" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/slack_notifier"
  output_path = "${path.module}/lambda/slack_notifier.zip"
}

resource "aws_iam_role" "slack_notifier" {
  name = "${local.project}-slack-notifier-${local.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "slack_notifier_logs" {
  role       = aws_iam_role.slack_notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "slack_notifier" {
  name              = "/aws/lambda/${local.project}-slack-notifier-${local.environment}"
  retention_in_days = 14
}

resource "aws_lambda_function" "slack_notifier" {
  function_name    = "${local.project}-slack-notifier-${local.environment}"
  role             = aws_iam_role.slack_notifier.arn
  runtime          = "python3.13"
  handler          = "index.handler"
  filename         = data.archive_file.slack_notifier.output_path
  source_code_hash = data.archive_file.slack_notifier.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      SLACK_WEBHOOK_URL = data.aws_ssm_parameter.slack_webhook_url.value
    }
  }

  depends_on = [aws_cloudwatch_log_group.slack_notifier]

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

# =============================================================================
# CloudWatch Alarms
# =============================================================================

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
  alarm_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# --- Public API ---

resource "aws_cloudwatch_metric_alarm" "public_api_errors" {
  alarm_name          = "${local.project}-${local.environment}-public-api-errors"
  alarm_description   = "Public API Lambda が 5分間で 5 件以上エラーを出した"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda.function_name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "public_api_throttles" {
  alarm_name          = "${local.project}-${local.environment}-public-api-throttles"
  alarm_description   = "Public API Lambda がスロットリングされた"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda.function_name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "public_api_p99_latency" {
  alarm_name          = "${local.project}-${local.environment}-public-api-p99-latency"
  alarm_description   = "Public API Lambda の p99 レイテンシが 10 秒を超えた"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda.function_name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.alarm_tags
}

# --- Admin API ---

resource "aws_cloudwatch_metric_alarm" "admin_api_errors" {
  alarm_name          = "${local.project}-${local.environment}-admin-api-errors"
  alarm_description   = "Admin API Lambda が 5分間で 1 件以上エラーを出した"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda_admin.function_name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.alarm_tags
}

resource "aws_cloudwatch_metric_alarm" "admin_api_throttles" {
  alarm_name          = "${local.project}-${local.environment}-admin-api-throttles"
  alarm_description   = "Admin API Lambda がスロットリングされた"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda_admin.function_name }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.alarm_tags
}

# --- API Gateway (Public API) ---

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${local.project}-${local.environment}-api-gateway-5xx"
  alarm_description   = "API Gateway が 5分間で 5 件以上の 5xx を返した"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { ApiId = module.api_gateway.api_id }
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  tags                = local.alarm_tags
}
