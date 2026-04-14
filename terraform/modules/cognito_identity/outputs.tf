output "identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.id
}

output "identity_pool_arn" {
  description = "ARN of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.arn
}
