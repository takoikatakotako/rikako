module "ecr_api" {
  source = "../../modules/ecr"

  repository_name      = "rikako-api"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  max_image_count      = 5
  allowed_account_ids  = local.allowed_account_ids

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}
