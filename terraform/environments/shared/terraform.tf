terraform {
  backend "s3" {
    bucket       = "rikako-terraform-state"
    key          = "shared/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
