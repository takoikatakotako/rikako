# Neon Project
resource "neon_project" "this" {
  name      = var.project_name
  region_id = var.region_id

  default_endpoint_settings {
    autoscaling_limit_min_cu = var.autoscaling_min_cu
    autoscaling_limit_max_cu = var.autoscaling_max_cu
    suspend_timeout_seconds  = var.suspend_timeout_seconds
  }
}

# Main branch (created automatically with project)
# We'll use the default branch for simplicity

# Database
resource "neon_database" "this" {
  project_id = neon_project.this.id
  branch_id  = neon_project.this.default_branch_id
  name       = var.database_name
  owner_name = neon_project.this.database_user
}

# Get connection string from the default branch endpoint
data "neon_branch" "default" {
  project_id = neon_project.this.id
  id         = neon_project.this.default_branch_id
}
