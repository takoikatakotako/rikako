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

  # タグ付きイメージ（:prod / :dev など使用中のもの）は保護し、untagged のみ
  # 一定期間経過後に削除する。以前は tagStatus=any で件数制限していたため、
  # dev の連続デプロイで prod が使用中の :prod イメージまで削除され、prod Lambda が
  # ImageDeleted で起動不能になる事故が発生した。
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} days (tagged images are kept)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countNumber = var.untagged_expiry_days
          countUnit   = "days"
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
