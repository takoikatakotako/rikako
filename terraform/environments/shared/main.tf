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

# Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}
