# Neon Project
resource "neon_project" "default" {
  name                      = "${local.project}-${local.environment}"
  region_id                 = "aws-ap-southeast-1" # Singapore
  history_retention_seconds = 21600                # 6 hours

  default_endpoint_settings {
    autoscaling_limit_min_cu = 0.25
    autoscaling_limit_max_cu = 2

    # 0 は「プラン既定値を使う」であって「常時起動」ではない。常時起動にするなら -1。
    # Free プランではそもそもこの値を変更できず、既定の 5 分で自動サスペンドする。
    # https://api-docs.neon.tech/reference/createprojectendpoint
    suspend_timeout_seconds = 0
  }
}

# Role
resource "neon_role" "default" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "rikako_owner"
}

# Database
resource "neon_database" "default" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "rikako"
  owner_name = neon_role.default.name
}
