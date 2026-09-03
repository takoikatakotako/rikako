# Neon Project
resource "neon_project" "default" {
  name                      = "${local.project}-${local.environment}"
  region_id                 = "aws-ap-southeast-1" # Singapore
  history_retention_seconds = 21600                # 6 hours (plan maximum)

  default_endpoint_settings {
    autoscaling_limit_min_cu = 0.25
    autoscaling_limit_max_cu = 4

    # 0 は「プラン既定値を使う」であって「常時起動」ではない。常時起動にするなら -1。
    # Free プランではそもそもこの値を変更できず、既定の 5 分で自動サスペンドする。
    # 実測でも自動サスペンドが効いている（2.4 日でコンピュート消費 0.2 CU 時間・
    # アクティブ 49 分。常時起動なら最低 12 CU 時間になるはず）。
    # https://api-docs.neon.tech/reference/createprojectendpoint
    suspend_timeout_seconds = 0
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

  # suspend_timeout_seconds は指定しない。Free プランでは変更が許可されておらず、
  # 値を渡すと apply が 412 "modifying the suspend interval is not permitted on
  # this account" で失敗する。Neon の既定（5 分で自動サスペンド）に任せる。
}

output "neon_readonly_endpoint_host" {
  description = "週次レポートが接続する読み取り専用エンドポイント（書き込みは 25006 で拒否される）"
  value       = neon_endpoint.readonly.host
}

# =============================================================================
# 週次レポート用のロール
# =============================================================================
# アプリの neondb_owner を使い回さず、レポート専用の認証情報を持たせる。
# 接続文字列が漏れてもローテーションはこのロールだけで済み、アプリを止めずにすむ。
#
# **重要**: このロールは DB 権限としては最小権限ではない。
#
# Neon が API/コンソールで作るロールは neon_superuser のメンバーになり、
# neon_superuser は pg_read_all_data と **pg_write_all_data** を持つ。
# つまりこのロールは GRANT 無しで全テーブルを読めるが、同時に書き換えもできてしまう
# （本番で has_table_privilege を確認済み: users/user_answers とも INSERT/UPDATE/DELETE = true）。
#
# 読み取り専用を担保しているのは **上の read_only エンドポイントだけ**。したがって
# 接続先は必ず neon_endpoint.readonly.host にすること。通常の read_write エンドポイントへ
# 向けると、このロールで本番を書き換えられる。下の output はその組み合わせを固定した
# 接続文字列を返すので、これをそのまま使う。
#
# 権限側でも縛るには SELECT だけのロールを SQL で作る必要があるが、GRANT は Terraform で
# 管理できず、手作業がコードの外に残るため採らない。
resource "neon_role" "report" {
  project_id = neon_project.default.id
  branch_id  = neon_project.default.default_branch_id
  name       = "rikako_report"
}

# レポートが使う接続文字列。read_only エンドポイント + レポート専用ロールの組み合わせ。
#
# apply 後、これを GCP Secret Manager へ入れる（レポートは gcp-iac 側で動くため）:
#
#   terraform output -raw neon_report_connection_uri \
#     | gcloud secrets versions add rikako-neon-report-url --data-file=- \
#       --project=takoikatakotako-analytics
output "neon_report_connection_uri" {
  description = "週次レポート用の接続文字列（読み取り専用エンドポイント経由）"
  value       = "postgresql://${neon_role.report.name}:${neon_role.report.password}@${neon_endpoint.readonly.host}/neondb?sslmode=require"
  sensitive   = true
}
