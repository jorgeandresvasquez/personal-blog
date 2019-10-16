provider "aws" {
  region  = "us-east-2"
  version = "~> 1.51.0"
}

terraform {
  backend "s3" {
    bucket = "com-billpayments-terraform-dev"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}