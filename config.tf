terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
      "org:owner"   = var.owner
      "org:project" = var.project_name
    }
  }
}
