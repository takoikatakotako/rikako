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

  # メール設定
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "main" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.main.id

  # モバイル/SPA用（シークレットなし）
  generate_secret = false

  # SRP認証フロー
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
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
