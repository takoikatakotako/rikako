variable "name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to integrate"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

variable "custom_domain_name" {
  description = "Custom domain name for the API"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
}

variable "throttle_burst_limit" {
  description = "Throttling burst limit (requests per second)"
  type        = number
  default     = 100
}

variable "throttle_rate_limit" {
  description = "Throttling rate limit (requests per second)"
  type        = number
  default     = 50
}

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "CORS allowed methods"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_headers" {
  description = "CORS allowed headers"
  type        = list(string)
  default     = ["*"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
