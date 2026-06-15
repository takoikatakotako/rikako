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
# ACM Certificate Validation
# *.rikako.org と rikako.org は同じ検証 CNAME を共有するため lp_cert_validation を参照
# =============================================================================

resource "aws_acm_certificate_validation" "wildcard" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in cloudflare_record.lp_cert_validation : record.hostname]
}

resource "aws_acm_certificate_validation" "wildcard_regional" {
  certificate_arn         = aws_acm_certificate.wildcard_regional.arn
  validation_record_fqdns = [for record in cloudflare_record.lp_cert_validation : record.hostname]
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

# docs.rikako.org → Docs CloudFront
resource "cloudflare_record" "docs" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "docs"
  content = aws_cloudfront_distribution.docs.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
