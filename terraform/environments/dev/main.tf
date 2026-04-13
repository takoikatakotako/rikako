# Lambda Function (Public API)
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${local.project}-api-${local.environment}"
  image_uri     = "579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api:dev"
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 512

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
  }

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
  custom_domain_name   = "api.dev.rikako.jp"
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
    DATABASE_URL                     = neon_project.default.connection_uri
    PORT                             = "8080"
    ENVIRONMENT                      = local.environment
    IMAGE_BASE_URL                   = "https://${module.image_cloudfront.domain_name}"
    IMAGE_S3_BUCKET                  = local.image_bucket_name
    CONTENT_S3_BUCKET                = local.content_bucket_name
    CONTENT_BASE_URL                 = "https://content.dev.rikako.jp"
    AWS_LWA_READINESS_CHECK_PROTOCOL = "http"
    AWS_LWA_READINESS_CHECK_PORT     = "8080"
    AWS_LWA_READINESS_CHECK_PATH     = "/health"
  }

  log_retention_days = 7

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

