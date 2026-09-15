# =============================================================================
# GitHub Actions - terraform plan 専用ロール（Issue #370）
# =============================================================================
# plan-terraform.yml は pull_request で動き、**PR に書かれた HCL をそのまま**
# terraform plan で評価する。共有の rikako-development-github-actions は
# AdministratorAccess を持つため、そのロールを渡すと「PR の内容が dev の管理者権限で
# 評価される」ことになる（provider の設定や external data source を通じて任意の
# API 呼び出しに化けうる）。
#
# 対策は2段構えにする。
#
# 1. 信頼を GitHub Environment（terraform-plan-dev）に限定する。この Environment には
#    required reviewers を設定してあるので、**承認されるまで OIDC トークンが発行されない**。
#    つまり PR のコードに AWS 認証情報が渡る前に、人間が差分を見る。
#    pull_request コンテキストのままでは、ブランチを push できる人が書いた HCL が
#    無条件に dev の認証情報を受け取ってしまう。
#
# 2. 権限は読み取りだけにする（prod の同名ロールと同じ ReadOnlyAccess）。
#
# なお、権限をさらに絞っても「plan に秘密値が渡ること」自体は無くせない。dev の provider は
# plan 時に SecureString（neon-api-key / admin-basic-auth-* / database-url）を復号して読むため、
# plan を実行できる＝その値を扱えるということになる。だからこそ 1 の承認ゲートを主対策に置く。

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
      # PR のワークフローでも、terraform-plan-dev Environment を要求するジョブ
      # （＝承認ゲートを通ったジョブ）だけが assume できる。
      values = ["repo:takoikatakotako/rikako:environment:terraform-plan-dev"]
    }
  }
}

resource "aws_iam_role" "gha_terraform_plan" {
  name = "${local.project}-${local.environment}-github-actions-terraform-plan"
  # IAM の CreateRole は Description を ASCII / Latin-1 に限定しているため日本語は使えない。
  description        = "Read-only role for plan-terraform; requires the terraform-plan-dev environment approval"
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
