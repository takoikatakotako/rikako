output "ecr_api_repository_url" {
  description = "URL of the API ECR repository"
  value       = module.ecr_api.repository_url
}

output "ecr_api_repository_arn" {
  description = "ARN of the API ECR repository"
  value       = module.ecr_api.repository_arn
}

output "ecr_admin_api_repository_url" {
  description = "URL of the Admin API ECR repository"
  value       = module.ecr_admin_api.repository_url
}

output "ecr_admin_api_repository_arn" {
  description = "ARN of the Admin API ECR repository"
  value       = module.ecr_admin_api.repository_arn
}
