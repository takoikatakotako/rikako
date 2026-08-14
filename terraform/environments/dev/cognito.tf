module "cognito" {
  source         = "../../modules/cognito"
  user_pool_name = "${local.project}-${local.environment}"
  client_name    = "${local.project}-mobile-${local.environment}"

  # SES 経由でメール送信（ドメイン検証完了後に適用されるよう depends_on）。
  email_source_arn   = aws_ses_domain_identity.main.arn
  email_from_address = local.ses_from_email

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_ses_domain_identity_verification.main]
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
