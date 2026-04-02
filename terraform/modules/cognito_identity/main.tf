resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = var.identity_pool_name
  allow_unauthenticated_identities = true
  allow_classic_flow               = false

  tags = var.tags
}

# IAM Role for unauthenticated users
data "aws_iam_policy_document" "unauthenticated_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = [aws_cognito_identity_pool.main.id]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["unauthenticated"]
    }
  }
}

resource "aws_iam_role" "unauthenticated" {
  name               = "${var.identity_pool_name}-unauthenticated"
  assume_role_policy = data.aws_iam_policy_document.unauthenticated_assume_role.json

  tags = var.tags
}

# Minimal policy — unauthenticated users only need Cognito identity access
data "aws_iam_policy_document" "unauthenticated_policy" {
  statement {
    effect = "Allow"
    actions = [
      "cognito-identity:GetId",
      "cognito-identity:GetCredentialsForIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "unauthenticated" {
  name   = "unauthenticated-policy"
  role   = aws_iam_role.unauthenticated.id
  policy = data.aws_iam_policy_document.unauthenticated_policy.json
}

# Attach role to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    "unauthenticated" = aws_iam_role.unauthenticated.arn
  }
}
