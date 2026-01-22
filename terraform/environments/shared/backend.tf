terraform {
  backend "s3" {
    bucket         = "rikako-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "rikako-terraform-locks"
    encrypt        = true
  }
}
