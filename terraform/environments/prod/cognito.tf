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

module "cognito_identity" {
  source             = "../../modules/cognito_identity"
  identity_pool_name = "${local.project}-${local.environment}"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
