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

  name                = local.content_bucket_name
  origin_domain_name  = module.content_s3.bucket_regional_domain_name
  origin_id           = "s3-${local.content_bucket_name}"
  comment             = "Content CDN for ${local.content_bucket_name}"
  aliases             = ["content.rikako.org"]
  acm_certificate_arn = aws_acm_certificate_validation.wildcard.certificate_arn
  default_ttl         = 60
  max_ttl             = 300

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

# =============================================================================
# GitHub Actions - コンテンツ CDN の invalidation
# =============================================================================
# Deploy All Prod の publish job が使う（Issue #358）。
#
# publish は S3 のオブジェクトを上書きするだけで、CloudFront のキャッシュは消えない。
# JSON の Cache-Control は max-age=60、ディストリビューションの default_ttl も 60 なので、
# publish 直前に edge に載った古い JSON が最大 60 秒返り続ける。問題集 Web は
# ビルド時にこの JSON を焼き込むため、待たずに web を建てると古い内容が本番に出る。
#
# そのため publish の後に invalidation を作り、完了を待ってから web をビルドする。
# GetInvalidation は完了待ちに必要。
# （ListDistributions は docs_cdn.tf の github_actions_s3_docs で付与済み）
resource "aws_iam_role_policy" "github_actions_content_invalidation" {
  name   = "content-cdn-invalidation"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_content_invalidation.json
}

data "aws_iam_policy_document" "github_actions_content_invalidation" {
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [module.content_cloudfront.distribution_arn]
  }
}
