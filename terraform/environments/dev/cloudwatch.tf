# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.project}-${local.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # --- Public API ---
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Public API (${module.lambda.function_name})"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Invocations"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda.function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Duration (ms)"
          region = var.region
          period = 300
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", module.lambda.function_name, { stat = "Average" }],
            ["...", { stat = "p99" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Errors / Throttles"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", module.lambda.function_name],
            ["AWS/Lambda", "Throttles", "FunctionName", module.lambda.function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Concurrent Executions"
          region = var.region
          stat   = "Maximum"
          period = 300
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", module.lambda.function_name],
          ]
        }
      },

      # --- Admin API ---
      {
        type   = "text"
        x      = 0
        y      = 13
        width  = 24
        height = 1
        properties = {
          markdown = "# Admin API (${module.lambda_admin.function_name})"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "Invocations"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda_admin.function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "Duration (ms)"
          region = var.region
          period = 300
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", module.lambda_admin.function_name, { stat = "Average" }],
            ["...", { stat = "p99" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "Errors / Throttles"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", module.lambda_admin.function_name],
            ["AWS/Lambda", "Throttles", "FunctionName", module.lambda_admin.function_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 20
        width  = 12
        height = 6
        properties = {
          title  = "Concurrent Executions"
          region = var.region
          stat   = "Maximum"
          period = 300
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", module.lambda_admin.function_name],
          ]
        }
      },
    ]
  })
}
