terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "aws" {
  region = "us-east-2"

  # Allow any 2.x version of the AWS provider
  version = "~> 2.0"
}

terraform {
  backend "s3" {
    bucket         = "terraform-blog-jv"
    key            = "staging/blog-website/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks-jv"
    encrypt        = true
  }
}

module "labels" {
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"

  tags = {
    Stage       = var.stage
    Project     = var.project
  }
}

module "s3_website" {
  source           = "git::https://github.com/cloudposse/terraform-aws-s3-website.git?ref=tags/0.8.0"
  namespace        = "blog"
  stage            = var.stage
  name             = "static-site"
  hostname         = "blog.staging.thepragmaticloud.com"
  parent_zone_name = "thepragmaticloud.com"
  force_destroy    = true
  error_document   = "error.html"
  tags             = module.labels.tags
}