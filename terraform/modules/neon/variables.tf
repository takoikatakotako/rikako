variable "project_name" {
  description = "Name of the Neon project"
  type        = string
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "rikako"
}

variable "region_id" {
  description = "Neon region ID"
  type        = string
  default     = "aws-ap-northeast-1"
}

variable "autoscaling_min_cu" {
  description = "Minimum compute units for autoscaling"
  type        = number
  default     = 0.25
}

variable "autoscaling_max_cu" {
  description = "Maximum compute units for autoscaling"
  type        = number
  default     = 2
}

variable "suspend_timeout_seconds" {
  description = "Auto-suspend timeout in seconds"
  type        = number
  default     = 300
}
