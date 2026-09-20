# =============================================================================
# DB バックアップの鮮度監視（Issue #331）
# =============================================================================
# backup-db-prod.yml（GitHub Actions）の日次バックアップが「静かに止まった」ことを
# GitHub の外から検知する。EventBridge Scheduler が毎日 Lambda を起動し、S3 の最新
# ダンプの LastModified が閾値より古ければ既存の SNS（→ slack_notifier → Slack）へ流す。
#
# GitHub 側で監視しないのは、監視したい故障（schedule の自動停止・Actions の障害）が
# 監視側も一緒に止めるため。費用は Scheduler / Lambda / S3 List とも無料枠内。
# =============================================================================

locals {
  backup_freshness_max_age_hours = 48 # 日次 + 1 日分の遅延・再実行の余地
}

data "archive_file" "backup_freshness" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/backup_freshness"
  output_path = "${path.module}/lambda/backup_freshness.zip"
}

resource "aws_iam_role" "backup_freshness" {
  name = "${local.project}-backup-freshness-${local.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "backup_freshness_logs" {
  role       = aws_iam_role.backup_freshness.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "backup_freshness" {
  name = "s3-list-and-sns-publish"
  role = aws_iam_role.backup_freshness.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 一覧だけ。ダンプ本体（GetObject）は読ませない
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = module.db_backup.bucket_arn
        Condition = {
          StringLike = { "s3:prefix" = ["${local.environment}/*", local.environment] }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerts.arn
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "backup_freshness" {
  name              = "/aws/lambda/${local.project}-backup-freshness-${local.environment}"
  retention_in_days = 30
}

resource "aws_lambda_function" "backup_freshness" {
  function_name    = "${local.project}-backup-freshness-${local.environment}"
  role             = aws_iam_role.backup_freshness.arn
  runtime          = "python3.13"
  handler          = "index.handler"
  filename         = data.archive_file.backup_freshness.output_path
  source_code_hash = data.archive_file.backup_freshness.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BUCKET        = module.db_backup.bucket_id
      PREFIX        = "${local.environment}/"
      MAX_AGE_HOURS = tostring(local.backup_freshness_max_age_hours)
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.backup_freshness]

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# --- EventBridge Scheduler（毎日 1 回）---
# バックアップは 18:10 UTC（backup-db-prod.yml）。その約 3 時間後に確認する。

resource "aws_iam_role" "backup_freshness_scheduler" {
  name = "${local.project}-backup-freshness-scheduler-${local.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "backup_freshness_scheduler" {
  name = "invoke-backup-freshness"
  role = aws_iam_role.backup_freshness_scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.backup_freshness.arn
    }]
  })
}

resource "aws_scheduler_schedule" "backup_freshness" {
  name        = "${local.project}-backup-freshness-${local.environment}"
  description = "prod DB バックアップの鮮度を毎日確認する（#331）"

  schedule_expression          = "cron(10 21 * * ? *)" # 21:10 UTC = 06:10 JST
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.backup_freshness.arn
    role_arn = aws_iam_role.backup_freshness_scheduler.arn

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 3600
    }
  }
}

# Lambda 自身が壊れて黙るケースを拾う（監視の監視。既存の SNS へ）。
resource "aws_cloudwatch_metric_alarm" "backup_freshness_errors" {
  alarm_name          = "${local.project}-${local.environment}-backup-freshness-errors"
  alarm_description   = "バックアップ鮮度チェック Lambda がエラー終了した（監視自体が止まっている可能性）"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.backup_freshness.function_name
  }
  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions
  tags          = local.alarm_tags
}
