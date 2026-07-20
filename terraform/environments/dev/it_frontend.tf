# it.dev.rikako.org — ITパスポート過去問Webアプリ（静的サイト）
# 公開サイトのため Basic Auth なし。Next.js の静的エクスポート（trailingSlash）を
# S3 + CloudFront で配信し、ディレクトリ/拡張子なしパスに index.html を補完する。

locals {
  it_bucket_name = "${local.project}-it-${local.environment}"
}

module "it_s3" {
  source = "../../modules/s3"

  bucket_name = local.it_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudfront_origin_access_control" "it" {
  name                              = local.it_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# dev は Basic 認証で保護し、検索ボットや一般アクセスを遮断する（prod では付けない）。
# 認証情報は既存の admin dev 資格情報（SSM）を流用。認証後に、ディレクトリ/拡張子なし
# パスへ index.html を補完する（全ページ静的生成済みなので SPA フォールバックは不要）。
resource "aws_cloudfront_function" "it_dir_index" {
  name    = "${local.project}-it-dir-index-${local.environment}"
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
          headers: { 'www-authenticate': { value: 'Basic realm="IT Dev"' } },
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

resource "aws_cloudfront_distribution" "it" {
  origin {
    domain_name              = module.it_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.it_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.it.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "IT past-questions web for ${local.project}-${local.environment}"
  default_root_object = "index.html"
  aliases             = ["it.dev.rikako.org"]

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${local.it_bucket_name}"
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
      function_arn = aws_cloudfront_function.it_dir_index.arn
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

resource "aws_s3_bucket_policy" "it_cdn" {
  bucket = module.it_s3.bucket_id
  policy = data.aws_iam_policy_document.it_cdn_s3_access.json
}

data "aws_iam_policy_document" "it_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.it_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.it.arn]
    }
  }
}

# it.dev.rikako.org → IT Web CloudFront
resource "cloudflare_record" "it" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "it.dev"
  content = aws_cloudfront_distribution.it.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
