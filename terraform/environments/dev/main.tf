# =============================================================================
# Lambda 環境変数の SSM 参照
# =============================================================================
# シークレットは Lambda 環境変数に値を直接埋め込まず、SSM Parameter Store の
# パスを "ssm:..." 形式で参照する。アプリ側 (internal/secrets.Resolve または
# slack_notifier の _resolve_ssm) が起動時に実値を取得する。
#
# 事前準備（手動）:
#   aws ssm put-parameter --name /rikako/development/openai-api-key \
#     --value 'sk-...' --type SecureString
#   aws ssm put-parameter --name /rikako/development/slack-contact-webhook-url \
#     --value 'https://hooks.slack.com/services/...' --type SecureString
#
# DATABASE_URL は neon_project の connection_uri から Terraform が SecureString として登録する。
# =============================================================================

resource "aws_ssm_parameter" "database_url" {
  name        = "/${local.project}/${local.environment}/database-url"
  type        = "SecureString"
  value       = neon_project.default.connection_uri
  description = "Neon DB connection URI (managed by Terraform)"
}

locals {
  api_ssm_param_names = [
    "/${local.project}/${local.environment}/openai-api-key",
    "/${local.project}/${local.environment}/slack-contact-webhook-url",
    aws_ssm_parameter.database_url.name,
  ]
  admin_api_ssm_param_names = [
    aws_ssm_parameter.database_url.name,
  ]

  ssm_param_arn_prefix = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter"
}

# Lambda Function (Public API)
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${local.project}-api-${local.environment}"
  image_uri     = "579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api:dev"
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 512

  cognito_identity_pool_arn = module.cognito_identity.identity_pool_arn

  environment_variables = {
    DATABASE_URL                     = "ssm:${aws_ssm_parameter.database_url.name}"
    PORT                             = "8080"
    ENVIRONMENT                      = local.environment
    IMAGE_BASE_URL                   = "https://${module.image_cloudfront.domain_name}"
    AWS_LWA_READINESS_CHECK_PROTOCOL = "http"
    AWS_LWA_READINESS_CHECK_PORT     = "8080"
    AWS_LWA_READINESS_CHECK_PATH     = "/health"
    COGNITO_USER_POOL_ID             = module.cognito.user_pool_id
    COGNITO_REGION                   = "ap-northeast-1"
    COGNITO_IDENTITY_POOL_ID         = module.cognito_identity.identity_pool_id
    MINIMUM_VERSION                  = "1.0.0"
    LATEST_VERSION                   = "1.0.0"
    OPENAI_API_KEY                   = "ssm:/${local.project}/${local.environment}/openai-api-key"
    SLACK_WEBHOOK_URL                = "ssm:/${local.project}/${local.environment}/slack-contact-webhook-url"
  }

  ssm_parameter_arns = [for name in local.api_ssm_param_names : "${local.ssm_param_arn_prefix}${name}"]

  create_function_url = false
  log_retention_days  = 7

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# API Gateway HTTP API (Public API)
module "api_gateway" {
  source = "../../modules/api_gateway"

  name                 = "${local.project}-api-${local.environment}"
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  custom_domain_name   = "api.dev.rikako.org"
  acm_certificate_arn  = aws_acm_certificate_validation.wildcard_regional.certificate_arn
  throttle_burst_limit = 100
  throttle_rate_limit  = 50

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# Lambda Function (Admin API)
module "lambda_admin" {
  source = "../../modules/lambda"

  function_name          = "${local.project}-admin-api-${local.environment}"
  function_url_auth_type = "AWS_IAM"
  image_uri              = "579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-admin-api:dev"
  architectures          = ["arm64"]
  timeout                = 30
  memory_size            = 512

  environment_variables = {
    DATABASE_URL                     = "ssm:${aws_ssm_parameter.database_url.name}"
    PORT                             = "8080"
    ENVIRONMENT                      = local.environment
    IMAGE_BASE_URL                   = "https://${module.image_cloudfront.domain_name}"
    IMAGE_S3_BUCKET                  = local.image_bucket_name
    CONTENT_S3_BUCKET                = local.content_bucket_name
    CONTENT_BASE_URL                 = "https://content.dev.rikako.org"
    AWS_LWA_READINESS_CHECK_PROTOCOL = "http"
    AWS_LWA_READINESS_CHECK_PORT     = "8080"
    AWS_LWA_READINESS_CHECK_PATH     = "/health"
  }

  ssm_parameter_arns = [for name in local.admin_api_ssm_param_names : "${local.ssm_param_arn_prefix}${name}"]

  log_retention_days = 7

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

