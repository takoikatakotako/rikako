output "ecr_api_repository_url" {
  description = "URL of the API ECR repository"
  value       = module.ecr_api.repository_url
}

output "ecr_api_repository_arn" {
  description = "ARN of the API ECR repository"
  value       = module.ecr_api.repository_arn
}
