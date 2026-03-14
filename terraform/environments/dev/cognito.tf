module "cognito" {
  source         = "../../modules/cognito"
  user_pool_name = "${local.project}-${local.environment}"
  client_name    = "${local.project}-mobile-${local.environment}"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
