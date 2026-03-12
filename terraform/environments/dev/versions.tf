terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.6"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = var.aws_profile != "" ? var.aws_profile : null
}

data "aws_ssm_parameter" "neon_api_key" {
  name = "/rikako/neon-api-key"
}

provider "neon" {
  api_key = data.aws_ssm_parameter.neon_api_key.value
}
