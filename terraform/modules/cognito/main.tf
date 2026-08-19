resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name

  # Email認証
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  # セルフ登録有効
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # パスワードポリシー（デフォルト）
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # メール設定。email_source_arn（SES ID の ARN）を渡すと SES(DEVELOPER)経由、
  # 空なら Cognito 既定（COGNITO_DEFAULT、1日50通・差出人固定）。
  email_configuration {
    email_sending_account = var.email_source_arn != "" ? "DEVELOPER" : "COGNITO_DEFAULT"
    source_arn            = var.email_source_arn != "" ? var.email_source_arn : null
    from_email_address    = var.email_from_address != "" ? var.email_from_address : null
  }

  # 確認コードメールの日本語化。サインアップ確認コードとパスワード再設定コードの
  # 両方に適用される。本文には必ずコード差し込みの {####} を含める。
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "【Rikako】確認コード"
    email_message        = "Rikako の確認コードは {####} です。アプリの画面に入力してください。心当たりのない場合は、このメールを破棄してください。"
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "main" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.main.id

  # モバイル/SPA用（シークレットなし）
  generate_secret = false

  # ユーザー不存在を認証・パスワード回復の応答差から悟らせない（メアド列挙対策）。
  # 直接パスワード認証を持つネット配布クライアントのため ENABLED を明示（#283）。
  prevent_user_existence_errors = "ENABLED"

  # 認証フロー
  # - USER_SRP_AUTH: SRP（将来利用）
  # - USER_PASSWORD_AUTH: email+password を TLS でそのまま送る。Amplify 非依存で
  #   cognito-idp を直叩きする iOS/Web の実装コストを抑えるため有効化（設計 §5.1 / #283）。
  # - REFRESH_TOKEN_AUTH: トークン更新
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # トークン有効期限
  access_token_validity  = 1  # 1時間
  id_token_validity      = 1  # 1時間
  refresh_token_validity = 30 # 30日

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}
