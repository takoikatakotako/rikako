locals {
  content_bucket_name = "${local.project}-content-${local.environment}"
}

# S3 Bucket for content JSON
module "content_s3" {
  source = "../../modules/s3"

  bucket_name = local.content_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# CloudFront for content delivery
module "content_cloudfront" {
  source = "../../modules/cloudfront"

  name               = local.content_bucket_name
  origin_domain_name = module.content_s3.bucket_regional_domain_name
  origin_id          = "s3-${local.content_bucket_name}"
  comment            = "Content CDN for ${local.content_bucket_name}"
  aliases            = ["content.dev.rikako.jp"]
  acm_certificate_arn = aws_acm_certificate_validation.wildcard.certificate_arn
  default_ttl        = 60
  max_ttl            = 300

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# S3 Bucket Policy - Allow CloudFront access via OAC
resource "aws_s3_bucket_policy" "content_cdn" {
  bucket = module.content_s3.bucket_id
  policy = data.aws_iam_policy_document.content_cdn_s3_access.json
}

data "aws_iam_policy_document" "content_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.content_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.content_cloudfront.distribution_arn]
    }
  }
}
