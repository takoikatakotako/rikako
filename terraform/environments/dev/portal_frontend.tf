# account.dev.rikako.org — Rikako アカウントポータル（ログイン/新規登録）
# Next.js 静的エクスポートを S3 + CloudFront で配信。既存の *.dev.rikako.org
# ワイルドカード証明書に乗る（apex ではなくサブドメイン）。
# localStorage に refresh token を置くため、独立 origin + 厳格 CSP を必須とする（#306 レビュー）。

locals {
  portal_bucket_name = "${local.project}-portal-${local.environment}"
}

module "portal_s3" {
  source = "../../modules/s3"

  bucket_name = local.portal_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudfront_origin_access_control" "portal" {
  name                              = local.portal_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# dev は Basic 認証で保護（検索ボット・一般アクセス遮断）。認証後に、ディレクトリ/
# 拡張子なしパスへ index.html を補完（全ページ静的生成済み）。
# 注: Basic 認証は CloudFront 配信物のみ。ブラウザからの cognito-idp / API 呼び出しは
# 直接飛ぶため影響しない。
resource "aws_cloudfront_function" "portal_dir_index" {
  name    = "${local.project}-portal-dir-index-${local.environment}"
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
          headers: { 'www-authenticate': { value: 'Basic realm="Portal Dev"' } },
        };
      }
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

# CSP + セキュリティヘッダ。connect-src を self + Cognito + API に限定し、第三者
# スクリプトを禁止することで XSS 時のトークン持ち出しリスクを低減する（完全遮断ではない：
# script-src に 'unsafe-inline' が残るため、注入コードは許可済み API を操作しうる）。
# 'unsafe-inline' は Next 静的エクスポートのインライン hydration のため（nonce はサーバーレス
# 配信では付けられない）。本番前に CSP report-only / hash ベース運用の可否を検討する。
resource "aws_cloudfront_response_headers_policy" "portal" {
  name = "${local.project}-portal-security-${local.environment}"

  security_headers_config {
    content_security_policy {
      override = true
      content_security_policy = join("; ", [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data:",
        "font-src 'self'",
        "connect-src 'self' https://cognito-idp.ap-northeast-1.amazonaws.com https://api.dev.rikako.org",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'",
        "frame-ancestors 'none'",
      ])
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }
}

resource "aws_cloudfront_distribution" "portal" {
  origin {
    domain_name              = module.portal_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.portal_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.portal.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Account portal for ${local.project}-${local.environment}"
  default_root_object = "index.html"
  aliases             = ["account.dev.rikako.org"]

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "s3-${local.portal_bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.portal.id

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
      function_arn = aws_cloudfront_function.portal_dir_index.arn
    }
  }

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

resource "aws_s3_bucket_policy" "portal_cdn" {
  bucket = module.portal_s3.bucket_id
  policy = data.aws_iam_policy_document.portal_cdn_s3_access.json
}

data "aws_iam_policy_document" "portal_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.portal_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.portal.arn]
    }
  }
}

# account.dev.rikako.org → Portal CloudFront
resource "cloudflare_record" "portal" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "account.dev"
  content = aws_cloudfront_distribution.portal.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
