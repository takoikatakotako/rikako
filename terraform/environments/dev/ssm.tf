# =============================================================================
# 手動登録の SSM パラメータ（値は Terraform 管理外、#394）
# =============================================================================
# 「どのパラメータが存在すべきか」を IaC で見えるようにするため、名前・型・説明だけを
# Terraform で持つ。値は state にも tfvars にも書かず、`lifecycle.ignore_changes = [value]`
# で Terraform が触らないようにしている（database-url と同じ扱い）。
#
# - 初回は既存パラメータを import する（ssm_imports.tf）。resource を書いて apply すると
#   "already exists" で失敗するため、import なしで作らないこと
# - 値の登録・更新は従来通り `aws ssm put-parameter --overwrite`（Firebase 設定は
#   scripts/firebase-config.sh push）。value の placeholder は新規作成時にしか使われない
# - 参照側（Lambda 環境変数の "ssm:..."、IAM の resource ARN）は文字列を直書きせず、
#   ここの `.name` / `.arn` を参照する
# - `/rikako/neon-api-key` と `/rikako/cloudflare-api-token` は provider の初期化に使うため
#   対象外（data source のまま。versions.tf 参照）
# =============================================================================

locals {
  # 新規作成時の仮の値。ignore_changes により既存パラメータの値は上書きされない。
  ssm_placeholder_value = "CHANGE_ME"

  # Firebase の iOS アプリ（app_slug）。plist は bundle ID ごとに 1 つ
  firebase_ios_app_slugs = ["high-school-chemistry", "it-passport"]

  # パラメータ名。resource の name と、IAM ポリシー（data source）の両方から参照する。
  # data "aws_iam_policy_document" が resource 属性に依存すると、その resource に変更が
  # ある plan では読み取りが apply まで遅延して差分が見えなくなるため、IAM 側は
  # resource ではなくこの文字列を参照する。
  ssm_param_names = {
    openai_api_key            = "/${local.project}/${local.environment}/openai-api-key"
    slack_contact_webhook_url = "/${local.project}/${local.environment}/slack-contact-webhook-url"
    slack_alert_webhook_url   = "/${local.project}/${local.environment}/slack-alert-webhook-url"
    firebase_android          = "/${local.project}/${local.environment}/firebase/android"
    admin_basic_auth_user     = "/${local.project}/admin-basic-auth-user"
    admin_basic_auth_password = "/${local.project}/admin-basic-auth-password"
  }
  firebase_ios_param_names = {
    for slug in local.firebase_ios_app_slugs : slug => "/${local.project}/${local.environment}/firebase/ios/${slug}"
  }
}

# --- 公開 API（Lambda 環境変数から ssm:/... で参照）---

resource "aws_ssm_parameter" "openai_api_key" {
  name        = local.ssm_param_names.openai_api_key
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "OpenAI API key for the AI chat endpoint (value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "slack_contact_webhook_url" {
  name        = local.ssm_param_names.slack_contact_webhook_url
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Slack incoming webhook for the contact form (value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}

# --- 監視（slack_notifier Lambda / DB バックアップの失敗通知）---

resource "aws_ssm_parameter" "slack_alert_webhook_url" {
  name        = local.ssm_param_names.slack_alert_webhook_url
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Slack incoming webhook for CloudWatch alarms (value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}

# --- Firebase クライアント設定（git 管理外。scripts/firebase-config.sh で出し入れ）---

resource "aws_ssm_parameter" "firebase_ios" {
  for_each = local.firebase_ios_param_names

  name        = each.value
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Firebase GoogleService-Info.plist for iOS app ${each.key} (value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "firebase_android" {
  name        = local.ssm_param_names.firebase_android
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Firebase google-services.json for Android (all apps in the project; value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}

# --- 管理画面の Basic 認証（環境プレフィックス無し。CloudFront Function に埋め込む）---

resource "aws_ssm_parameter" "admin_basic_auth_user" {
  name        = local.ssm_param_names.admin_basic_auth_user
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Basic auth user for the admin console (value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "admin_basic_auth_password" {
  name        = local.ssm_param_names.admin_basic_auth_password
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Basic auth password for the admin console (value managed out-of-band)"

  lifecycle {
    ignore_changes = [value]
  }
}
