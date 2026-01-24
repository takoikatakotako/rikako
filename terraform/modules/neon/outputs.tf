output "project_id" {
  description = "ID of the Neon project"
  value       = neon_project.this.id
}

output "database_host" {
  description = "Database host"
  value       = neon_project.this.database_host
}

output "database_name" {
  description = "Database name"
  value       = neon_database.this.name
}

output "database_user" {
  description = "Database user"
  value       = neon_project.this.database_user
}

output "database_password" {
  description = "Database password"
  value       = neon_project.this.database_password
  sensitive   = true
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgres://${neon_project.this.database_user}:${neon_project.this.database_password}@${neon_project.this.database_host}/${neon_database.this.name}?sslmode=require"
  sensitive   = true
}
