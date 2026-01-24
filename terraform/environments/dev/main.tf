# Lambda Function
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${local.project}-api-${local.environment}"
  image_uri     = "579039992557.dkr.ecr.ap-northeast-1.amazonaws.com/rikako-api:dev"
  timeout       = 30
  memory_size   = 512

  environment_variables = {
    DATABASE_URL                      = neon_project.default.connection_uri
    PORT                              = "8080"
    ENVIRONMENT                       = local.environment
    IMAGE_BASE_URL                    = "https://example.com"
    AWS_LWA_READINESS_CHECK_PROTOCOL  = "http"
    AWS_LWA_READINESS_CHECK_PORT      = "8080"
    AWS_LWA_READINESS_CHECK_PATH      = "/health"
  }

  log_retention_days = 7

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
