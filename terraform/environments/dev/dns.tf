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
# ACM Wildcard Certificate (ap-northeast-1, required for API Gateway)
# =============================================================================

resource "aws_acm_certificate" "wildcard_regional" {
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

resource "aws_acm_certificate_validation" "wildcard_regional" {
  certificate_arn         = aws_acm_certificate.wildcard_regional.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# =============================================================================
# Route 53 Records
# =============================================================================

# api.dev.rikako.jp → API Gateway
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.dev.zone_id
  name    = "api.dev.rikako.jp"
  type    = "A"

  alias {
    name                   = module.api_gateway.custom_domain_target
    zone_id                = module.api_gateway.custom_domain_hosted_zone_id
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
