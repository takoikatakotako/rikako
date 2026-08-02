variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "中身が入っていても destroy を許可する（再配信可能な静的コンテンツ用バケット向け）"
  type        = bool
  default     = false
}
