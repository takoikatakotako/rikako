# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.github_actions_oidc_thumbprint]
}

# Assume Role Policy for GitHub Actions
data "aws_iam_policy_document" "github_actions_assume_role" {
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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:takoikatakotako/rikako:*"]
    }
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name               = "${local.project}-${local.environment}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# ReadOnly access for Terraform Plan
resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# S3 Terraform state lock access for GitHub Actions
resource "aws_iam_role_policy" "github_actions_terraform_state" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3_state.json
}

data "aws_iam_policy_document" "github_actions_s3_state" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::rikako-terraform-state/*.tflock",
    ]
  }
}

# S3 bucket policy for Terraform state cross-account access
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = "rikako-terraform-state"
  policy = data.aws_iam_policy_document.terraform_state_access.json
}

data "aws_iam_policy_document" "terraform_state_access" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        for account_id in local.allowed_account_ids :
        "arn:aws:iam::${account_id}:role/${local.project}-development-github-actions"
      ]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::rikako-terraform-state",
      "arn:aws:s3:::rikako-terraform-state/*",
    ]
  }
}
