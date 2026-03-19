variable "name" {
  description = "Name for the Origin Access Control"
  type        = string
}

variable "origin_domain_name" {
  description = "Domain name of the origin (e.g., S3 bucket regional domain)"
  type        = string
}

variable "origin_id" {
  description = "Unique identifier for the origin"
  type        = string
}

variable "comment" {
  description = "Comment for the CloudFront distribution"
  type        = string
  default     = ""
}

variable "default_ttl" {
  description = "Default TTL in seconds"
  type        = number
  default     = 86400
}

variable "max_ttl" {
  description = "Maximum TTL in seconds"
  type        = number
  default     = 31536000
}

variable "aliases" {
  description = "CNAMEs (alternate domain names) for the distribution"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
