# =============================================================================
# 手動登録の SSM パラメータ（値は Terraform 管理外、#394）
# =============================================================================
# 「どのパラメータが存在すべきか」を IaC で見えるようにするため、名前・型・説明だけを
# Terraform で持つ。値は構成（tfvars 含む）には書かず、`lifecycle.ignore_changes = [value]`
# で Terraform が上書きしないようにしている（database-url と同じ扱い）。
# ただし ignore_changes は差分を apply 対象から外すだけで、import / refresh で読んだ
# 復号済みの値は remote state（S3、暗号化・アクセス制限済み）に入る。state の保護要件は
# database-url と同じく「シークレットを含む」前提で扱うこと。
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
  # Android の Play 用署名素材のマスター（#405）。scripts/android-signing.sh push が SSM と
  # GitHub Secrets の両方に書き、CI は Secrets を読む。SSM は記録と手元での pull 用なので
  # GitHub Actions ロールには読み取り権限を付けない。
  android_signing_param_names = {
    upload_keystore          = "/${local.project}/${local.environment}/android/upload-keystore"
    upload_keystore_password = "/${local.project}/${local.environment}/android/upload-keystore-password"
    upload_key_alias         = "/${local.project}/${local.environment}/android/upload-key-alias"
    upload_key_password      = "/${local.project}/${local.environment}/android/upload-key-password"
    play_service_account     = "/${local.project}/${local.environment}/android/play-service-account"
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

# --- Android の Play 用署名素材（マスター。手元の初回アップロードが pull する）---

resource "aws_ssm_parameter" "android_signing" {
  for_each = local.android_signing_param_names

  name        = each.value
  type        = "SecureString"
  value       = local.ssm_placeholder_value
  description = "Android Play upload signing material: ${each.key} (value managed out-of-band via scripts/android-signing.sh)"

  lifecycle {
    ignore_changes = [value]
  }
}
