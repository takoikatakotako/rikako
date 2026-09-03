# Neon Project
resource "neon_project" "default" {
  name                      = "${local.project}-${local.environment}"
  region_id                 = "aws-ap-southeast-1" # Singapore
  history_retention_seconds = 21600                # 6 hours (plan maximum)

  default_endpoint_settings {
    autoscaling_limit_min_cu = 0.25
    autoscaling_limit_max_cu = 4
    suspend_timeout_seconds  = 0 # Always active (no auto-suspend)
  }

  lifecycle {
    ignore_changes = all
  }
}

# Role
#
# 注意: このロールと下の neon_database.default（rikako）は **アプリからは使われていない**。
# prod のアプリが実際に使うのは Neon デフォルトの neondb_owner / neondb で、そちらは
# 下の "app" として import してある。ここは Terraform 導入時に作られたまま残っている。
# 消すには DROP が必要で、rikako DB を所有しているため 422 ROLE_OWNS_OBJECTS になる
# （main.tf のローテーション手順のコメント参照）。触らずに残す。
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

# =============================================================================
# アプリが実際に使うロールとデータベース（Neon デフォルト）
# =============================================================================
# Neon がプロジェクト作成時に自動で用意したもので、Terraform の管理外だった。
# 管理下に置いておかないと、うっかり Neon コンソールから消したときに気づけない。
#
# password は Neon 側が持つ値をそのまま読み取る。ローテーションは Terraform ではなく
# Neon API の reset_password で行う（main.tf のコメント参照）。ロールは DB を所有して
# いるため drop/recreate できない（422 ROLE_OWNS_OBJECTS）ので、replace が出る変更は
# 絶対に apply しないこと。
resource "neon_role" "app" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "neondb_owner"
}

resource "neon_database" "app" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "neondb"
  owner_name = neon_role.app.name
}

# =============================================================================
# 週次レポート用の読み取り専用ロール
# =============================================================================
# gcp-iac の etl/rikako-neon が学習指標を集計するために使う。SELECT だけを持ち、
# アプリのオーナー権限（neondb_owner）は使い回さない。
#
# ロール自体は Neon が作るが、**SELECT 権限の付与は SQL でしか行えない**ため
# Terraform の管理外になる。ロールを作り直したときは以下を実行すること:
#
#   GRANT CONNECT ON DATABASE neondb TO rikako_readonly;
#   GRANT USAGE ON SCHEMA public TO rikako_readonly;
#   GRANT SELECT ON ALL TABLES IN SCHEMA public TO rikako_readonly;
#   ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public
#     GRANT SELECT ON TABLES TO rikako_readonly;
#
# 接続文字列は GCP Secret Manager の rikako-neon-readonly-url に置く
# （レポートが GCP 認証だけで完結するようにするため）。
resource "neon_role" "readonly" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "rikako_readonly"
}

# =============================================================================
# import（既存リソースを state へ取り込む）
# =============================================================================
# ID は <project_id>/<branch_id>/<name>。plan で確認してから apply する。
import {
  to = neon_role.app
  id = "fragrant-poetry-87067174/br-icy-field-aokksku7/neondb_owner"
}

import {
  to = neon_database.app
  id = "fragrant-poetry-87067174/br-icy-field-aokksku7/neondb"
}

import {
  to = neon_role.readonly
  id = "fragrant-poetry-87067174/br-icy-field-aokksku7/rikako_readonly"
}
