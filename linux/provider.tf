terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.40"
    }

    http = {
      source  = "hashicorp/http"
    }
  }
}

provider "aws" {
  region = var.region
}
