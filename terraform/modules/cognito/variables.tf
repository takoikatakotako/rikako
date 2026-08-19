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
  description = "SES identity ARN for sending emails (DEVELOPER)。本モジュールは常に SES 送信のため必須。"
  type        = string
}

variable "email_from_address" {
  description = "SES 経由メールの差出人（例: no-reply@rikako.org）。"
  type        = string
}
