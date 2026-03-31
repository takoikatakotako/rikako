# =============================================================================
# Route 53 Hosted Zone for dev.rikako.jp
# =============================================================================

resource "aws_route53_zone" "dev" {
  name = "dev.rikako.jp"
}

# =============================================================================
# ACM Wildcard Certificate (us-east-1, required for CloudFront)
# =============================================================================

resource "aws_acm_certificate" "wildcard" {
  provider          = aws.us_east_1
  domain_name       = "*.dev.rikako.jp"
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

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.dev.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "wildcard" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# =============================================================================
# CloudFront Distribution for Public API (api.dev.rikako.jp)
# =============================================================================

locals {
  api_origin_domain = trimsuffix(trimprefix(module.lambda.function_url, "https://"), "/")
}

resource "aws_cloudfront_distribution" "api" {
  origin {
    domain_name = local.api_origin_domain
    origin_id   = "lambda-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Public API for ${local.project}-${local.environment}"
  aliases         = ["api.dev.rikako.jp"]

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "lambda-api"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers", "Authorization"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
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
# Route 53 Records (A Alias → CloudFront)
# =============================================================================

# api.dev.rikako.jp → Public API CloudFront
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "api.dev.rikako.jp"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}

# image.dev.rikako.jp → Image CDN CloudFront
resource "aws_route53_record" "image" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "image.dev.rikako.jp"
  type    = "A"

  alias {
    name                   = module.image_cloudfront.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront global hosted zone ID
    evaluate_target_health = false
  }
}

# content.dev.rikako.jp → Content CDN CloudFront
resource "aws_route53_record" "content" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "content.dev.rikako.jp"
  type    = "A"

  alias {
    name                   = module.content_cloudfront.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront global hosted zone ID
    evaluate_target_health = false
  }
}

# admin.dev.rikako.jp → Admin Frontend CloudFront
resource "aws_route53_record" "admin" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "admin.dev.rikako.jp"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.admin.domain_name
    zone_id                = aws_cloudfront_distribution.admin.hosted_zone_id
    evaluate_target_health = false
  }
}
