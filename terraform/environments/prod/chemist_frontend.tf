# chemist.rikako.org — 高校化学 問題集Webアプリ（静的サイト・一般公開）
# it_frontend.tf と同型（共通コードベース web/ を NEXT_PUBLIC_SITE=chemistry でビルドして配信）。
# LP と同様、Basic Auth なしの公開サイト。

locals {
  chemist_bucket_name = "${local.project}-chemist-${local.environment}"
}

module "chemist_s3" {
  source = "../../modules/s3"

  bucket_name = local.chemist_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudfront_origin_access_control" "chemist" {
  name                              = local.chemist_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 公開サイトなので認証なし。ディレクトリ/拡張子なしパスに index.html を補完するだけ。
resource "aws_cloudfront_function" "chemist_dir_index" {
  name    = "${local.project}-chemist-dir-index-${local.environment}"
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

resource "aws_cloudfront_distribution" "chemist" {
  origin {
    domain_name              = module.chemist_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.chemist_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.chemist.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Chemistry web for ${local.project}-${local.environment}"
  default_root_object = "index.html"
  aliases             = ["chemist.rikako.org"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${local.chemist_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 86400

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.chemist_dir_index.arn
    }
  }

  # 存在しないパスは 404.html（Next.js が出力）を返す
  custom_error_response {
    error_code         = 404
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

resource "aws_s3_bucket_policy" "chemist_cdn" {
  bucket = module.chemist_s3.bucket_id
  policy = data.aws_iam_policy_document.chemist_cdn_s3_access.json
}

data "aws_iam_policy_document" "chemist_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.chemist_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.chemist.arn]
    }
  }
}

# =============================================================================
# GitHub Actions - S3 Chemistry frontend upload access
# （ListDistributions は docs_cdn.tf の github_actions_s3_docs で付与済み）
# =============================================================================

resource "aws_iam_role_policy" "github_actions_s3_chemist" {
  name   = "s3-chemist-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3_chemist.json
}

data "aws_iam_policy_document" "github_actions_s3_chemist" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.chemist_s3.bucket_arn,
      "${module.chemist_s3.bucket_arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.chemist.arn]
  }
}

# chemist.rikako.org → Chemistry Web CloudFront
resource "cloudflare_record" "chemist" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "chemist"
  content = aws_cloudfront_distribution.chemist.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
