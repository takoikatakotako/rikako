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

output "api_endpoint" {
  description = "URL of the public API"
  value       = "https://api.rikako.org"
}

output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = module.api_gateway.api_id
}

output "admin_function_url" {
  description = "URL of the admin API Lambda function"
  value       = module.lambda_admin.function_url
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

output "admin_frontend_url" {
  description = "URL of the admin frontend (CloudFront)"
  value       = "https://${aws_cloudfront_distribution.admin.domain_name}"
}

output "admin_frontend_distribution_id" {
  description = "CloudFront distribution ID for admin frontend"
  value       = aws_cloudfront_distribution.admin.id
}

output "admin_frontend_bucket" {
  description = "S3 bucket for admin frontend"
  value       = module.admin_s3.bucket_id
}

output "lp_url" {
  description = "URL of the LP"
  value       = "https://rikako.org"
}

output "lp_distribution_id" {
  description = "CloudFront distribution ID for LP"
  value       = aws_cloudfront_distribution.lp.id
}

output "lp_bucket" {
  description = "S3 bucket for LP"
  value       = module.lp_s3.bucket_id
}

