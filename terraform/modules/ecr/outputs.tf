output "repository_url" {
  description = "The URL of the repository"
  value       = aws_ecr_repository.default.repository_url
}

output "repository_arn" {
  description = "The ARN of the repository"
  value       = aws_ecr_repository.default.arn
}

output "repository_name" {
  description = "The name of the repository"
  value       = aws_ecr_repository.default.name
}

output "registry_id" {
  description = "The registry ID where the repository was created"
  value       = aws_ecr_repository.default.registry_id
}
