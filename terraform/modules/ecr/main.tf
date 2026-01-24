resource "aws_ecr_repository" "default" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "default" {
  repository = aws_ecr_repository.default.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "ecr_repository" {
  statement {
    sid    = "AllowPushPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for account_id in var.allowed_account_ids : "arn:aws:iam::${account_id}:root"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }

  statement {
    sid    = "LambdaECRImageRetrievalPolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]

    condition {
      test     = "StringLike"
      variable = "aws:sourceArn"
      values   = [for account_id in var.allowed_account_ids : "arn:aws:lambda:*:${account_id}:function:*"]
    }
  }

  statement {
    sid    = "LambdaECRImageCrossAccountRetrievalPolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    condition {
      test     = "StringLike"
      variable = "aws:sourceAccount"
      values   = var.allowed_account_ids
    }
  }
}

resource "aws_ecr_repository_policy" "default" {
  repository = aws_ecr_repository.default.name
  policy     = data.aws_iam_policy_document.ecr_repository.json
}
