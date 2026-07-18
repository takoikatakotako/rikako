# GitHub Actions 用 Terraform 実行ロール（plan / apply）。
# apply-terraform-prod.yml（workflow_dispatch）から使用する。
#
# 設計（Issue #240）:
# - plan ロール : ReadOnlyAccess。ゲート無し（main の workflow から assume 可）。読み取り専用なので安全。
# - apply ロール: AdministratorAccess。信頼を environment:production に限定し、
#                 GitHub Environment の承認を通った apply ジョブからしか assume できない。
#
# 注意（public リポ）:
# - plan の出力ログは terraform の sensitive 伝播で秘匿値が (sensitive value) に伏字化される。
# - 一方 plan のバイナリファイルは伏字化されないため、アーティファクトとして公開しない
#   （apply ジョブは承認後に再 plan して適用する）。

# --- plan ロール（ReadOnly / ゲート無し） ---
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
      values   = ["repo:takoikatakotako/rikako:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha_terraform_plan" {
  name               = "${local.project}-${local.environment}-github-actions-terraform-plan"
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

# ReadOnlyAccess には kms:Decrypt が含まれない。プロバイダ設定が SecureString の
# SSM パラメータ（neon-api-key / cloudflare-api-token / admin-basic-auth-* / database-url）を
# plan 時に復号して読むため、SSM 経由の復号だけを許可する。
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

# --- apply ロール（Administrator / environment:production 限定） ---
data "aws_iam_policy_document" "gha_terraform_apply_assume" {
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

    # environment:production を要求する GitHub Actions ジョブ（＝承認ゲートを通ったジョブ）のみ許可
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:takoikatakotako/rikako:environment:production"]
    }
  }
}

resource "aws_iam_role" "gha_terraform_apply" {
  name               = "${local.project}-${local.environment}-github-actions-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.gha_terraform_apply_assume.json

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "gha_terraform_apply_admin" {
  role       = aws_iam_role.gha_terraform_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_terraform_plan_role_arn" {
  value = aws_iam_role.gha_terraform_plan.arn
}

output "github_actions_terraform_apply_role_arn" {
  value = aws_iam_role.gha_terraform_apply.arn
}
