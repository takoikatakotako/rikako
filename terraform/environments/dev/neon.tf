# Neon Project
resource "neon_project" "default" {
  name                      = "${local.project}-${local.environment}"
  region_id                 = "aws-ap-southeast-1"  # Singapore
  history_retention_seconds = 21600                 # 6 hours

  default_endpoint_settings {
    autoscaling_limit_min_cu = 0.25
    autoscaling_limit_max_cu = 2
    suspend_timeout_seconds  = 0  # Always active (no auto-suspend)
  }
}

# Database
resource "neon_database" "default" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "rikako"
  owner_name = neon_project.default.database_user
}
