locals {
  image_bucket_name = "${local.project}-images-${local.environment}"
}

# S3 Bucket for images
module "image_s3" {
  source = "../../modules/s3"

  bucket_name = local.image_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# CloudFront for image delivery
module "image_cloudfront" {
  source = "../../modules/cloudfront"

  name               = local.image_bucket_name
  origin_domain_name = module.image_s3.bucket_regional_domain_name
  origin_id          = "s3-${local.image_bucket_name}"
  comment            = "Image CDN for ${local.image_bucket_name}"
  aliases            = ["image.dev.rikako.jp"]
  acm_certificate_arn = aws_acm_certificate_validation.wildcard.certificate_arn

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# S3 Bucket Policy - Allow CloudFront access via OAC
resource "aws_s3_bucket_policy" "image_cdn" {
  bucket = module.image_s3.bucket_id
  policy = data.aws_iam_policy_document.image_cdn_s3_access.json
}

data "aws_iam_policy_document" "image_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.image_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.image_cloudfront.distribution_arn]
    }
  }
}

# GitHub Actions - S3 image upload access
resource "aws_iam_role_policy" "github_actions_s3_images" {
  name   = "s3-images-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3_images.json
}

data "aws_iam_policy_document" "github_actions_s3_images" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.image_s3.bucket_arn,
      "${module.image_s3.bucket_arn}/*",
    ]
  }
}
