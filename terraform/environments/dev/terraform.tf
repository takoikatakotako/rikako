terraform {
  backend "s3" {
    bucket       = "rikako-dev-terraform-state"
    key          = "terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
