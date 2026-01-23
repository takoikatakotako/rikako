terraform {
  backend "s3" {
    bucket  = "rikako-terraform-state"
    key     = "dev/terraform.tfstate"
    region  = "ap-northeast-1"
    profile = "rikako-shared-sso"
    encrypt = true
  }
}
