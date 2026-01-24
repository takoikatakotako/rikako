variable "neon_api_key" {
  description = "Neon API key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}
