locals {
  environment = "shared"
  project     = "rikako"
  
  # Dev環境のアカウントID（ECRへのアクセスを許可）
  allowed_account_ids = ["197865631794"]
}
