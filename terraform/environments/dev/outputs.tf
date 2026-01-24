# output "function_url" {
#   description = "URL of the Lambda function"
#   value       = module.lambda.function_url
# }

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
