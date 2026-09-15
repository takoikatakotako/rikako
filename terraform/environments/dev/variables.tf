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

# plan 用ロールを assume できる唯一のワークフロー定義（Issue #370）。
# OIDC トークンの job_workflow_ref と突き合わせる。main のファイルを指すので、
# PR 側でワークフローを書き換えても一致しない。
variable "github_actions_terraform_plan_workflow_ref" {
  description = "job_workflow_ref allowed to assume the terraform plan role"
  type        = string
  default     = "takoikatakotako/rikako/.github/workflows/terraform-plan-trusted.yml@refs/heads/main"
}
