output "function_url" {
  description = "URL of the public API Lambda function"
  value       = module.lambda.function_url
}

output "admin_function_url" {
  description = "URL of the admin API Lambda function"
  value       = module.lambda_admin.function_url
}

output "database_host" {
  description = "Neon database host"
  value       = neon_project.default.database_host
  sensitive   = true
}

output "connection_string" {
  description = "Database connection string"
  value       = neon_project.default.connection_uri
  sensitive   = true
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = module.cognito.user_pool_endpoint
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.cognito.client_id
}
