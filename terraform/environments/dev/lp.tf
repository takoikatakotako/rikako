# dev.rikako.org — LP（rikako.org）の dev 環境
# prod の lp.tf と同型。違いは次の2点。
#   1. Basic 認証を付ける（他の dev サイトと同じ。検索エンジンに拾わせない）
#   2. force_destroy = true（dev は作り直しを許す）

locals {
  lp_bucket_name = "${local.project}-lp-${local.environment}"
  lp_domain      = "dev.rikako.org"
}

# =============================================================================
# ACM Certificate (us-east-1, required for CloudFront)
# *.dev.rikako.org ワイルドカードは apex（dev.rikako.org）を含まないため別途発行。
# prod で rikako.org 用に別証明書を切っているのと同じ理由。
# =============================================================================

resource "aws_acm_certificate" "lp" {
  provider          = aws.us_east_1
  domain_name       = local.lp_domain
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
# S3 Bucket
# =============================================================================

module "lp_s3" {
  source = "../../modules/s3"

  bucket_name   = local.lp_bucket_name
  force_destroy = true
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# CloudFront Distribution
# =============================================================================

resource "aws_cloudfront_origin_access_control" "lp" {
  name                              = local.lp_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Basic 認証 + クリーンURL の rewrite。
# rewrite 部分は prod の lp_rewrite と同じロジック（拡張子の無いパスに .html を付与）。
# dev は公開前の確認用なので、検索エンジンや一般アクセスを Basic 認証で遮断する。
resource "aws_cloudfront_function" "lp_rewrite" {
  name    = "${local.project}-lp-rewrite-${local.environment}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    var CREDENTIALS = '${local.admin_basic_auth_credentials}';
    function handler(event) {
      var request = event.request;
      var headers = request.headers;
      var auth = headers.authorization;
      if (!auth || auth.value !== 'Basic ' + CREDENTIALS) {
        return {
          statusCode: 401,
          statusDescription: 'Unauthorized',
          headers: { 'www-authenticate': { value: 'Basic realm="LP Dev"' } },
        };
      }
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
  comment             = "LP for ${local.project}-${local.environment}"
  default_root_object = "index.html"
  aliases             = [local.lp_domain]

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

    # dev は確認のたびに反映されてほしいので prod より短くする。
    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 86400

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
# Cloudflare DNS Record
# dev.rikako.org → LP CloudFront
# ※ dev.rikako.org は SES のドメイン検証にも使っているが、あちらが追加するのは
#    _domainkey などのサブドメインの TXT/CNAME なので、この CNAME とは衝突しない。
# =============================================================================

resource "cloudflare_record" "lp" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "dev"
  content = aws_cloudfront_distribution.lp.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
