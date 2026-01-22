terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.6"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "neon" {
  api_key = var.neon_api_key
}
