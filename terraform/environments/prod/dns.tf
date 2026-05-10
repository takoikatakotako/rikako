# =============================================================================
# Cloudflare Zone
# =============================================================================

data "cloudflare_zone" "rikako" {
  name = "rikako.org"
}

# =============================================================================
# ACM Wildcard Certificate (us-east-1, required for CloudFront)
# =============================================================================

resource "aws_acm_certificate" "wildcard" {
  provider          = aws.us_east_1
  domain_name       = "*.rikako.org"
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

# =============================================================================
# ACM Wildcard Certificate (ap-northeast-1, required for API Gateway)
# =============================================================================

resource "aws_acm_certificate" "wildcard_regional" {
  domain_name       = "*.rikako.org"
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

# =============================================================================
# Cloudflare DNS Records for ACM Certificate Validation
# =============================================================================

resource "cloudflare_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "wildcard" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in cloudflare_record.cert_validation : record.hostname]
}

resource "aws_acm_certificate_validation" "wildcard_regional" {
  certificate_arn         = aws_acm_certificate.wildcard_regional.arn
  validation_record_fqdns = [for record in cloudflare_record.cert_validation : record.hostname]
}

# =============================================================================
# Cloudflare DNS Records
# =============================================================================

# api.rikako.org → API Gateway
resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "api"
  content = module.api_gateway.custom_domain_target
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# image.rikako.org → Image CDN CloudFront
resource "cloudflare_record" "image" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "image"
  content = module.image_cloudfront.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# content.rikako.org → Content CDN CloudFront
resource "cloudflare_record" "content" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "content"
  content = module.content_cloudfront.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# admin.rikako.org → Admin Frontend CloudFront
resource "cloudflare_record" "admin" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "admin"
  content = aws_cloudfront_distribution.admin.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
