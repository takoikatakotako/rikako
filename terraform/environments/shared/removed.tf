# shared アカウント(579039992557)の ECR / OIDC / GitHub Actions ロールの管理を、
# 組織横断の IaC リポジトリ aws-iac(terraform/accounts/shared)へ移管する。
#
# 実体は aws-iac 側が state で保持しているため、このリポジトリでは state から
# 除去するだけで破棄しない。`lifecycle { destroy = false }` により
# `terraform state rm` 相当（forget only、実インフラは変更なし）となる。
#
# apply 後、この shared 環境ディレクトリ自体は別途撤去する。

removed {
  from = module.ecr_api
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.ecr_admin_api
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_openid_connect_provider.github_actions
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role.github_actions
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy.github_actions_terraform_state
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy_attachment.github_actions_readonly
  lifecycle {
    destroy = false
  }
}
