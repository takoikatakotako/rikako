# =============================================================================
# GitHub Actions - datasync plan 専用ロール（Issue #370）
# =============================================================================
# plan-datasync は PR のソースから datasync をビルドして実行する。共有の
# rikako-development-github-actions は AdministratorAccess を持つため、そのロールを
# 渡すと「PR に書いたコードが dev の管理者権限で動く」ことになる。
#
# plan がやるのは「SSM から接続URLを読み、DB を読んで YAML と突き合わせる」だけなので、
# 専用ロールを用意して権限をそこまでに絞る。
#
# DB 側の権限はこのロールでは絞れない（接続URLの示す Neon ロールの権限になる）。
# 読み取り専用の Neon ロールを用意して plan 用に分けるのは残件。

data "aws_iam_policy_document" "datasync_plan_assume_role" {
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

    # plan-datasync が動く 2 経路だけに限定する。
    #   - pull_request: PR での差分確認
    #   - ref:refs/heads/main: main からの workflow_dispatch（job 側でも main に限定済み）
    # 共有ロールの repo:...:* と違い、他のブランチやタグからは assume できない。
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:takoikatakotako/rikako:pull_request",
        "repo:takoikatakotako/rikako:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "datasync_plan" {
  name               = "${local.project}-${local.environment}-github-actions-datasync-plan"
  description        = "plan-datasync 専用。SSM から dev の接続URLを読むだけ"
  assume_role_policy = data.aws_iam_policy_document.datasync_plan_assume_role.json

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "datasync_plan_ssm" {
  name   = "ssm-database-url-read"
  role   = aws_iam_role.datasync_plan.id
  policy = data.aws_iam_policy_document.datasync_plan_ssm.json
}

# SecureString の復号に kms:Decrypt を別途足す必要はない。このパラメータは key_id を
# 指定していないため AWS 管理キー（alias/aws/ssm）で暗号化されており、そのキーポリシーが
# SSM 経由の呼び出しにアカウント内プリンシパルからの復号を許している。prod の
# github_actions_ssm も ssm:GetParameter だけで --with-decryption が通っている。
data "aws_iam_policy_document" "datasync_plan_ssm" {
  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project}/${local.environment}/database-url",
    ]
  }
}

output "datasync_plan_role_arn" {
  description = "plan-datasync が assume するロール"
  value       = aws_iam_role.datasync_plan.arn
}
