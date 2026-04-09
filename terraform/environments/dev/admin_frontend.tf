data "aws_ssm_parameter" "admin_basic_auth_user" {
  name = "/rikako/admin-basic-auth-user"
}

data "aws_ssm_parameter" "admin_basic_auth_password" {
  name = "/rikako/admin-basic-auth-password"
}

locals {
  admin_bucket_name            = "${local.project}-admin-${local.environment}"
  admin_api_origin_domain      = trimsuffix(trimprefix(module.lambda_admin.function_url, "https://"), "/")
  admin_basic_auth_credentials = base64encode("${data.aws_ssm_parameter.admin_basic_auth_user.value}:${data.aws_ssm_parameter.admin_basic_auth_password.value}")
}

# S3 Bucket for admin frontend
module "admin_s3" {
  source = "../../modules/s3"

  bucket_name = local.admin_bucket_name
  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# CloudFront OAC for admin frontend (S3)
resource "aws_cloudfront_origin_access_control" "admin" {
  name                              = local.admin_bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront OAC for admin API (Lambda)
resource "aws_cloudfront_origin_access_control" "admin_api" {
  name                              = "${local.project}-admin-api-${local.environment}"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for Basic Auth + SPA rewrite (frontend)
resource "aws_cloudfront_function" "admin_spa_rewrite" {
  name    = "${local.project}-admin-spa-rewrite-${local.environment}"
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
          headers: { 'www-authenticate': { value: 'Basic realm="Admin"' } },
        };
      }
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (!uri.includes('.')) {
        var segments = uri.split('/').filter(function(s) { return s; });
        if (segments.length > 1) {
          request.uri = '/' + segments[0] + '/index.html';
        } else {
          request.uri = uri + '/index.html';
        }
      }
      return request;
    }
  EOF
}

# CloudFront Function for Basic Auth + API rewrite
resource "aws_cloudfront_function" "admin_api_auth_rewrite" {
  name    = "${local.project}-admin-api-auth-rewrite-${local.environment}"
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
          headers: { 'www-authenticate': { value: 'Basic realm="Admin"' } },
        };
      }
      request.uri = request.uri.replace(/^\/api/, '');
      if (request.uri === '') {
        request.uri = '/';
      }
      return request;
    }
  EOF
}

# CloudFront Distribution for admin (frontend + API)
resource "aws_cloudfront_distribution" "admin" {
  # Origin 1: S3 (frontend static files)
  origin {
    domain_name              = module.admin_s3.bucket_regional_domain_name
    origin_id                = "s3-${local.admin_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.admin.id
  }

  # Origin 2: Lambda Function URL (admin API) with OAC
  origin {
    domain_name              = local.admin_api_origin_domain
    origin_id                = "lambda-admin-api"
    origin_access_control_id = aws_cloudfront_origin_access_control.admin_api.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Admin (frontend + API) for ${local.project}-${local.environment}"
  default_root_object = "index.html"
  aliases             = ["admin.dev.rikako.jp"]

  # Default: S3 frontend
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${local.admin_bucket_name}"
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
      function_arn = aws_cloudfront_function.admin_spa_rewrite.arn
    }
  }

  # /api/* → Lambda admin API (with path rewrite)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "lambda-admin-api"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.admin_api_auth_rewrite.arn
    }
  }

  # SPA: return index.html for 403/404 (client-side routing)
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
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

# Lambda Permission - Allow CloudFront to invoke admin API via OAC
resource "aws_lambda_permission" "admin_cloudfront" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunctionUrl"
  function_name = module.lambda_admin.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.admin.arn
}

# S3 Bucket Policy - Allow CloudFront access via OAC
resource "aws_s3_bucket_policy" "admin_cdn" {
  bucket = module.admin_s3.bucket_id
  policy = data.aws_iam_policy_document.admin_cdn_s3_access.json
}

data "aws_iam_policy_document" "admin_cdn_s3_access" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.admin_s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.admin.arn]
    }
  }
}
