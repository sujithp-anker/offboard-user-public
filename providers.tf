terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.Region

  default_tags {
    tags = {
      Automation = "Terraform"
      Tool       = "Gaia-Offboarder"
      ManagedBy  = "DevOps"
    }
  }
}