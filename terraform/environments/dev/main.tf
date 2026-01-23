# # Data source for ECR repository (created in shared environment)
# data "aws_ecr_repository" "api" {
#   name = "rikako-api"
# }

# # Neon Database
# module "neon" {
#   source = "../../modules/neon"

#   project_name             = "${local.project}-${local.environment}"
#   database_name            = "rikako"
#   region_id                = "aws-ap-northeast-1"
#   autoscaling_min_cu       = 0.25
#   autoscaling_max_cu       = 2
#   suspend_timeout_seconds  = 300
# }

# # Lambda Function
# module "lambda" {
#   source = "../../modules/lambda"

#   function_name = "${local.project}-api-${local.environment}"
#   image_uri     = "${data.aws_ecr_repository.api.repository_url}:${local.environment}"
#   timeout       = 30
#   memory_size   = 512

#   environment_variables = {
#     DATABASE_URL = module.neon.connection_string
#     PORT         = "8080"
#     ENVIRONMENT  = local.environment
#   }

#   log_retention_days = 7

#   tags = {
#     Project     = local.project
#     Environment = local.environment
#     ManagedBy   = "terraform"
#   }
# }
