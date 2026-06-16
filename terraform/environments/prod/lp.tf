locals {
  lp_bucket_name = "${local.project}-lp"
}

# =============================================================================
# ACM Certificate for rikako.org (us-east-1, required for CloudFront)
# *.rikako.org ワイルドカードは apex を含まないため別途発行
# =============================================================================

resource "aws_acm_certificate" "lp" {
  provider          = aws.us_east_1
  domain_name       = "rikako.org"
  validation_method = "DNS"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "lp_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.lp.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      content = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.rikako.id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  ttl     = 300
  proxied = false
}

resource "aws_acm_certificate_validation" "lp" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.lp.arn
  validation_record_fqdns = [for record in cloudflare_record.lp_cert_validation : record.hostname]
}

# =============================================================================
# S3 Bucket for LP
# =============================================================================

module "lp_s3" {
  source = "../../modules/s3"

  bucket_name = local.lp_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# CloudFront Distribution for LP
# =============================================================================

resource "aws_cloudfront_origin_access_control" "lp" {
  name                              = local.lp_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# クリーンURL用の rewrite。拡張子の無いパスに .html を付与する
# （例: /privacy → /privacy.html, /terms/2026-06-16 → /terms/2026-06-16.html）。
# ルート / と拡張子付き(.css/.png 等)はそのまま。S3 静的サイトホスティングは使わず
# OAC を維持したまま、AWS 推奨の CloudFront Functions 方式でクリーンURLを実現する。
resource "aws_cloudfront_function" "lp_rewrite" {
  name    = "${local.project}-lp-rewrite-${local.environment}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri === '/') {
        return request;
      }
      if (uri.endsWith('/')) {
        uri = uri.slice(0, -1);
      }
      var lastSegment = uri.split('/').pop();
      if (lastSegment.indexOf('.') === -1) {
        uri = uri + '.html';
      }
      request.uri = uri;
      return request;
    }
  EOF
}

resource "aws_cloudfront_distribution" "lp" {
  origin {
    domain_name              = module.lp_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.lp_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.lp.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "LP for ${local.project}"
  default_root_object = "index.html"
  aliases             = ["rikako.org"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${local.lp_bucket_name}"
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
      function_arn = aws_cloudfront_function.lp_rewrite.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.lp.certificate_arn
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
# S3 Bucket Policy
# =============================================================================

resource "aws_s3_bucket_policy" "lp_cdn" {
  bucket = module.lp_s3.bucket_id
  policy = data.aws_iam_policy_document.lp_cdn_s3_access.json
}

data "aws_iam_policy_document" "lp_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.lp_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.lp.arn]
    }
  }
}

# =============================================================================
# GitHub Actions - S3 LP upload access
# =============================================================================

resource "aws_iam_role_policy" "github_actions_s3_lp" {
  name   = "s3-lp-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3_lp.json
}

data "aws_iam_policy_document" "github_actions_s3_lp" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.lp_s3.bucket_arn,
      "${module.lp_s3.bucket_arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.lp.arn]
  }
}

# =============================================================================
# Cloudflare DNS Record
# rikako.org → LP CloudFront (Cloudflare CNAME flattening で apex に対応)
# =============================================================================

resource "cloudflare_record" "lp" {
  zone_id         = data.cloudflare_zone.rikako.id
  name            = "rikako.org"
  content         = aws_cloudfront_distribution.lp.domain_name
  type            = "CNAME"
  ttl             = 1
  proxied         = false
  allow_overwrite = true
}
