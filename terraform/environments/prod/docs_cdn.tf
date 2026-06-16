locals {
  docs_bucket_name = "${local.project}-docs"
}

# =============================================================================
# S3 Bucket for docs (MkDocs build output)
# =============================================================================

module "docs_s3" {
  source = "../../modules/s3"

  bucket_name = local.docs_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# CloudFront Distribution for docs.rikako.org
# =============================================================================

resource "aws_cloudfront_origin_access_control" "docs" {
  name                              = local.docs_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ディレクトリインデックスの rewrite（MkDocs の use_directory_urls=true に対応）
# 例: /runbook/ → /runbook/index.html, /schema → /schema/index.html
# docs は公開のため Basic Auth は無し。
resource "aws_cloudfront_function" "docs_dir_index" {
  name    = "${local.project}-docs-dir-index-${local.environment}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (!uri.includes('.')) {
        request.uri = uri + '/index.html';
      }
      return request;
    }
  EOF
}

resource "aws_cloudfront_distribution" "docs" {
  origin {
    domain_name              = module.docs_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.docs_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.docs.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Docs for ${local.project}"
  default_root_object = "index.html"
  aliases             = ["docs.rikako.org"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${local.docs_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.docs_dir_index.arn
    }
  }

  # MkDocs Material が生成する 404.html を返す。
  # OAC + S3 では存在しないオブジェクトは 403 を返すため、403 も 404 ページにマップする。
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.wildcard.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# S3 Bucket Policy - Allow CloudFront access via OAC
# =============================================================================

resource "aws_s3_bucket_policy" "docs_cdn" {
  bucket = module.docs_s3.bucket_id
  policy = data.aws_iam_policy_document.docs_cdn_s3_access.json
}

data "aws_iam_policy_document" "docs_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.docs_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.docs.arn]
    }
  }
}

# =============================================================================
# GitHub Actions - S3 docs upload + CloudFront invalidation
# =============================================================================

resource "aws_iam_role_policy" "github_actions_s3_docs" {
  name   = "s3-docs-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3_docs.json
}

data "aws_iam_policy_document" "github_actions_s3_docs" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.docs_s3.bucket_arn,
      "${module.docs_s3.bucket_arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.docs.arn]
  }

  # docs.yml が alias から distribution id を動的解決するため
  statement {
    effect    = "Allow"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }
}
