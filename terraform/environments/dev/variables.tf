variable "aws_profile" {
  description = "AWS CLIプロファイル名。空文字の場合は環境変数の認証情報を使用する。"
  type        = string
  default     = "rikako-development-sso"
}

variable "neon_api_key" {
  description = "Neon API key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "github_actions_oidc_thumbprint" {
  description = "GitHub Actions OIDCエンドポイント（token.actions.githubusercontent.com）のルートCA証明書のサムプリント。AWS側で独自に検証するため実質任意の値でも動作するが、慣習的にこの既知の値を使用する。"
  type        = string
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}
