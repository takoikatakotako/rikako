# =============================================================================
# GitHub Actions - terraform plan 専用ロール（Issue #370）
# =============================================================================
# plan-terraform.yml は pull_request で動き、**PR に書かれた HCL をそのまま**
# terraform plan で評価する。共有の rikako-development-github-actions は
# AdministratorAccess を持つため、そのロールを渡すと「PR の内容が dev の管理者権限で
# 評価される」ことになる（provider の設定や external data source を通じて任意の
# API 呼び出しに化けうる）。
#
# plan に必要なのは読み取りだけなので、prod の
# rikako-production-github-actions-terraform-plan と同じ形で ReadOnly のロールを用意する。
# 信頼は pull_request コンテキストだけに限定する（このロールを使うのは plan のみ）。

data "aws_iam_policy_document" "gha_terraform_plan_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:takoikatakotako/rikako:pull_request"]
    }
  }
}

resource "aws_iam_role" "gha_terraform_plan" {
  name = "${local.project}-${local.environment}-github-actions-terraform-plan"
  # IAM の CreateRole は Description を ASCII / Latin-1 に限定しているため日本語は使えない。
  description        = "Read-only role for plan-terraform on pull requests"
  assume_role_policy = data.aws_iam_policy_document.gha_terraform_plan_assume.json

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "gha_terraform_plan_readonly" {
  role       = aws_iam_role.gha_terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess には kms:Decrypt が含まれない。dev も SecureString の SSM パラメータ
# （neon-api-key / admin-basic-auth-* / database-url）を plan 時に復号して読むため、
# SSM 経由の復号だけを許可する（prod の同名ロールと同じ）。
data "aws_iam_policy_document" "gha_terraform_plan_decrypt" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "gha_terraform_plan_decrypt" {
  name   = "ssm-securestring-decrypt"
  role   = aws_iam_role.gha_terraform_plan.id
  policy = data.aws_iam_policy_document.gha_terraform_plan_decrypt.json
}

output "gha_terraform_plan_role_arn" {
  description = "plan-terraform が assume するロール（Issue #370 で切り替える）"
  value       = aws_iam_role.gha_terraform_plan.arn
}
