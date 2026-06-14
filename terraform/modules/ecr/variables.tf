variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "untagged_expiry_days" {
  description = "Number of days after which untagged images are expired. Tagged images (e.g. :prod / :dev) are always kept."
  type        = number
  default     = 14
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_account_ids" {
  description = "List of AWS account IDs that are allowed to pull images"
  type        = list(string)
  default     = []
}
