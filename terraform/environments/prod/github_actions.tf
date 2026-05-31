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

# ECR Access Policy (shared account)
data "aws_iam_policy_document" "ecr_access" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [
      "arn:aws:ecr:${var.region}:579039992557:repository/rikako-api",
      "arn:aws:ecr:${var.region}:579039992557:repository/rikako-admin-api"
    ]
  }
}

resource "aws_iam_role_policy" "ecr_access" {
  name   = "ecr-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_access.json
}

# Lambda deploy access
resource "aws_iam_role_policy" "github_actions_lambda_deploy" {
  name   = "lambda-deploy-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_lambda_deploy.json
}

data "aws_iam_policy_document" "github_actions_lambda_deploy" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration", # aws lambda wait function-updated
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${local.project}-api-${local.environment}",
      "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${local.project}-admin-api-${local.environment}",
    ]
  }
}

# Admin frontend S3 deploy + CloudFront invalidation
resource "aws_iam_role_policy" "github_actions_admin_frontend" {
  name   = "admin-frontend-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_admin_frontend.json
}

data "aws_iam_policy_document" "github_actions_admin_frontend" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.admin_s3.bucket_arn,
      "${module.admin_s3.bucket_arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
    ]
    resources = [
      aws_cloudfront_distribution.admin.arn,
    ]
  }
}

# Terraform state read access (for migration workflow)
resource "aws_iam_role_policy" "github_actions_terraform_state" {
  name   = "terraform-state-read"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_terraform_state.json
}

data "aws_iam_policy_document" "github_actions_terraform_state" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::rikako-prod-terraform-state",
      "arn:aws:s3:::rikako-prod-terraform-state/*",
    ]
  }
}

# SSM read access (for smoke tests)
resource "aws_iam_role_policy" "github_actions_ssm" {
  name   = "ssm-read-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ssm.json
}

data "aws_iam_policy_document" "github_actions_ssm" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/rikako/admin-basic-auth-user",
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/rikako/admin-basic-auth-password",
    ]
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}
