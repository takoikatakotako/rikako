terraform {
  backend "s3" {
    bucket         = "rikako-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "rikako-terraform-locks"
    encrypt        = true
  }
}
