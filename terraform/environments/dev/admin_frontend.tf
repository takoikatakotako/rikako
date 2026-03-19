locals {
  admin_bucket_name       = "${local.project}-admin-${local.environment}"
  admin_api_origin_domain = trimsuffix(trimprefix(module.lambda_admin.function_url, "https://"), "/")
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

# CloudFront Function to strip /api prefix before forwarding to Lambda
resource "aws_cloudfront_function" "admin_api_rewrite" {
  name    = "${local.project}-admin-api-rewrite-${local.environment}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    function handler(event) {
      var request = event.request;
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

  # Origin 2: Lambda Function URL (admin API)
  origin {
    domain_name = local.admin_api_origin_domain
    origin_id   = "lambda-admin-api"

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
      function_arn = aws_cloudfront_function.admin_api_rewrite.arn
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
    cloudfront_default_certificate = true
  }

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
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
