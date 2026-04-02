variable "identity_pool_name" {
  description = "Name of the Cognito Identity Pool"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
