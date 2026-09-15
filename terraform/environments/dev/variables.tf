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

# plan-terraform を承認なしで動かせる GitHub ユーザーの ID（Issue #370）。
# PR のコードが AWS 認証情報を受け取れるのは、この ID が起こした PR だけ。
# 数値 ID は `gh api users/<login> --jq .id` で確認できる。
variable "github_actions_owner_actor_id" {
  description = "GitHub user id allowed to run plan-terraform on pull requests"
  type        = string
  default     = "7970479" # takoikatakotako
}
