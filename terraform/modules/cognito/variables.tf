variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
}

variable "client_name" {
  description = "Name of the Cognito User Pool Client"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "email_source_arn" {
  description = "SES identity ARN for sending emails (DEVELOPER). 空なら COGNITO_DEFAULT を使う。"
  type        = string
  default     = ""
}

variable "email_from_address" {
  description = "SES 経由メールの差出人（例: no-reply@dev.rikako.org）。email_source_arn 指定時に使う。"
  type        = string
  default     = ""
}
