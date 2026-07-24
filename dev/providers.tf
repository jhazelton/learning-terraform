terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84.0" # <-- Forces Terraform to stay on Version 5
    }
  }
}

provider "aws" {
  region  = "us-east-1"
}

