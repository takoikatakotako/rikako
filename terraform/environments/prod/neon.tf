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

# =============================================================================
# 週次レポート用の読み取り専用エンドポイント（Read Replica）
# =============================================================================
# gcp-iac の週次レポートが学習指標（回答数・正答率・ユーザー数）を集計するために使う。
#
# 読み取り専用「ロール」ではなく「コンピュート」を分ける。理由は 2 つ:
#
#   1. Neon のコンソール・CLI・API で作ったロールには neon_superuser が自動で付く。
#      権限を絞ったロールを作るには SQL しかなく、GRANT は Terraform で管理できない。
#      https://neon.com/docs/manage/roles
#   2. Read Replica なら読み取り専用が**コンピュート層で強制**される。接続するロールが
#      書き込み権限を持っていても、このエンドポイント経由の書き込みは
#      SQLSTATE 25006 で拒否される。GRANT の付け忘れという事故が起きない。
#      https://neon.com/docs/guides/read-only-access-read-replicas
#
# 既存の read_write エンドポイントには一切触れない（別コンピュートとして増える）。
# 1 ブランチに read_write は 1 つまでだが、read_only は追加できる。
#
# コストは Free プランの枠内。レポートは週 1 回で、繋いで数秒クエリしたら
# 5 分後にサスペンドする。0.25 CU × 6 分 × 月 4〜5 回 ≒ 0.12 CU 時間/月で、
# Free 枠 100 CU 時間に対して 0.1% 程度。Free プランはプロジェクトあたり
# read replica を 3 つまで持てる。
resource "neon_endpoint" "readonly" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  type       = "read_only"

  # レポートは週 1 回しか繋がない。最小構成にして、待機中はゼロにスケールさせる。
  autoscaling_limit_min_cu = 0.25
  autoscaling_limit_max_cu = 1

  # 5 分無操作でサスペンド。値を 0 にすると Neon の既定に従う。
  suspend_timeout_seconds = 300
}

output "neon_readonly_endpoint_host" {
  description = "週次レポートが接続する読み取り専用エンドポイント（書き込みは 25006 で拒否される）"
  value       = neon_endpoint.readonly.host
}
