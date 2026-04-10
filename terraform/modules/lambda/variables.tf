variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "image_uri" {
  description = "URI of the container image"
  type        = string
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "architectures" {
  description = "Lambda function architectures (x86_64 or arm64)"
  type        = list(string)
  default     = ["x86_64"]
}

variable "create_function_url" {
  description = "Whether to create a Lambda Function URL"
  type        = bool
  default     = true
}

variable "function_url_auth_type" {
  description = "Authorization type for Lambda Function URL (NONE or AWS_IAM)"
  type        = string
  default     = "NONE"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
