locals {
  environment = "shared"
  project     = "rikako"

  # Dev/Prod環境のアカウントID（ECRへのアクセスを許可）
  allowed_account_ids = ["197865631794", "211125415945"]
}
