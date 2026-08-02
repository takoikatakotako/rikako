# chemistry.dev.rikako.org — 高校化学 問題集Webアプリ（静的サイト）
# it_frontend.tf と同型（共通コードベース web/ を NEXT_PUBLIC_SITE=chemistry でビルドして配信）。
# dev は Basic 認証でボット/一般アクセスを遮断（prod では付けない）。
# ※ 旧 chemist_frontend.tf（chemist.dev.rikako.org）から並行移行中。旧スタックは後続PRで削除する。

locals {
  chemistry_bucket_name = "${local.project}-chemistry-${local.environment}"
}

module "chemistry_s3" {
  source = "../../modules/s3"

  bucket_name   = local.chemistry_bucket_name
  force_destroy = true
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudfront_origin_access_control" "chemistry" {
  name                              = local.chemistry_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "chemistry_dir_index" {
  name    = "${local.project}-chemistry-dir-index-${local.environment}"
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
          headers: { 'www-authenticate': { value: 'Basic realm="Chemistry Dev"' } },
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

resource "aws_cloudfront_distribution" "chemistry" {
  origin {
    domain_name              = module.chemistry_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.chemistry_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.chemistry.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Chemistry web for ${local.project}-${local.environment}"
  default_root_object = "index.html"
  aliases             = ["chemistry.dev.rikako.org"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${local.chemistry_bucket_name}"
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
      function_arn = aws_cloudfront_function.chemistry_dir_index.arn
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

resource "aws_s3_bucket_policy" "chemistry_cdn" {
  bucket = module.chemistry_s3.bucket_id
  policy = data.aws_iam_policy_document.chemistry_cdn_s3_access.json
}

data "aws_iam_policy_document" "chemistry_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.chemistry_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.chemistry.arn]
    }
  }
}

# chemistry.dev.rikako.org → Chemistry Web CloudFront
resource "cloudflare_record" "chemistry" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "chemistry.dev"
  content = aws_cloudfront_distribution.chemistry.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
