# =============================================================================
# OpenAI APIキー
# =============================================================================
# 事前準備: OpenAI APIキーを SSM Parameter Store に SecureString で保存
#   aws ssm put-parameter --name /rikako/production/openai-api-key \
#     --value 'sk-...' --type SecureString
# =============================================================================

data "aws_ssm_parameter" "openai_api_key" {
  name            = "/${local.project}/${local.environment}/openai-api-key"
  with_decryption = true
}

# =============================================================================
# Slack Webhook URL（お問い合わせ通知用）
# =============================================================================
# 事前準備: Slack Webhook URLを SSM Parameter Store に SecureString で保存
#   aws ssm put-parameter --name /rikako/production/slack-contact-webhook-url \
#     --value 'https://hooks.slack.com/services/...' --type SecureString
# =============================================================================

data "aws_ssm_parameter" "slack_contact_webhook_url" {
  name            = "/${local.project}/${local.environment}/slack-contact-webhook-url"
  with_decryption = true
}

# Lambda Function (Public API)
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${local.project}-api-${local.environment}"
  image_uri     = "579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api:prod"
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 512

  cognito_identity_pool_arn = module.cognito_identity.identity_pool_arn

  environment_variables = {
    DATABASE_URL                     = neon_project.default.connection_uri
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
    OPENAI_API_KEY                   = data.aws_ssm_parameter.openai_api_key.value
    SLACK_WEBHOOK_URL                = data.aws_ssm_parameter.slack_contact_webhook_url.value
  }

  create_function_url = false
  log_retention_days  = 30

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
  custom_domain_name   = "api.rikako.org"
  acm_certificate_arn  = aws_acm_certificate_validation.wildcard_regional.certificate_arn
  throttle_burst_limit = 200
  throttle_rate_limit  = 100

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
  image_uri              = "579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-admin-api:prod"
  architectures          = ["arm64"]
  timeout                = 30
  memory_size            = 512

  environment_variables = {
    DATABASE_URL                     = neon_project.default.connection_uri
    PORT                             = "8080"
    ENVIRONMENT                      = local.environment
    IMAGE_BASE_URL                   = "https://${module.image_cloudfront.domain_name}"
    IMAGE_S3_BUCKET                  = local.image_bucket_name
    CONTENT_S3_BUCKET                = local.content_bucket_name
    CONTENT_BASE_URL                 = "https://content.rikako.org"
    AWS_LWA_READINESS_CHECK_PROTOCOL = "http"
    AWS_LWA_READINESS_CHECK_PORT     = "8080"
    AWS_LWA_READINESS_CHECK_PATH     = "/health"
  }

  log_retention_days = 30

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
