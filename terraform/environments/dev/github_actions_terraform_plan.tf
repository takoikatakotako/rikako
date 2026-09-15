# =============================================================================
# GitHub Actions - terraform plan 専用ロール（Issue #370）
# =============================================================================
# plan-terraform.yml は pull_request で動き、**PR に書かれた HCL をそのまま**
# terraform plan で評価する。共有の rikako-development-github-actions は
# AdministratorAccess を持つため、そのロールを渡すと「PR の内容が dev の管理者権限で
# 評価される」ことになる（provider の設定や external data source を通じて任意の
# API 呼び出しに化けうる）。
#
# 境界の作り方:
#
# 1. **main に置いた信頼済みワークフローからしか assume できないようにする**。
#    OIDC トークンの job_workflow_ref は「実際に走っている workflow の定義がどの ref の
#    どのファイルか」を指し、PR 側からは書き換えられない（PR の caller が別ファイルに
#    差し替えても、そのファイルは main のものではないので一致しない）。
#    信頼済みワークフロー側で「PR の作成者がオーナー本人か」を検証してから plan する。
#
#    sub だけを見る条件（repo:...:pull_request）では、ブランチを push できる人が書いた
#    HCL が無条件に dev の認証情報を受け取ってしまう。actor_id の条件も不十分で、
#    actor は「run を開始したアカウント」であって PR の作成者ではない（他人の PR を
#    オーナーが reopen すると、オーナーの actor_id でその PR のコードが動く）。
#
# 2. 権限は読み取りだけにする（prod の同名ロールと同じ ReadOnlyAccess）。
#
# なお、権限をさらに絞っても「plan に秘密値が渡ること」自体は無くせない。dev の provider は
# plan 時に SecureString（neon-api-key / admin-basic-auth-* / database-url）を復号して読むため、
# plan を実行できる＝その値を扱えるということになる。だからこそ 1 の「誰の PR を、どの定義で
# 走らせるか」を PR 側から動かせない形にしている。

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

    # 使い道は PR 上の plan だけ。
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:takoikatakotako/rikako:pull_request"]
    }

    # main に置いた信頼済み reusable workflow の定義で走っている job だけに限定する。
    # PR 側で caller ワークフローを書き換えても、この値は main のファイルを指さない限り
    # 一致しないため、認証情報は発行されない。
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values   = [var.github_actions_terraform_plan_workflow_ref]
    }
  }
}

resource "aws_iam_role" "gha_terraform_plan" {
  name = "${local.project}-${local.environment}-github-actions-terraform-plan"
  # IAM の CreateRole は Description を ASCII / Latin-1 に限定しているため日本語は使えない。
  description        = "Read-only role for plan-terraform; assumable only from the trusted reusable workflow on main"
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
