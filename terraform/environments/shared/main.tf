# ECR Repository (shared across all environments)
module "ecr" {
  source = "../../modules/ecr"

  repository_name = "rikako-api"

  tags = {
    Project     = "rikako"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}
