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
    key            = "prod/blog-website/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks-jv"
    encrypt        = true
  }
}

module "labels" {
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"

  tags = {
    Stage       = var.stage
    Namespace     = var.namespace
  }
}

module "blog_website" {
  source                   = "git::https://github.com/jorgeandresvasquez/terraform.git//modules/s3-static-website-cdn?ref=0.0.4"
  namespace                = var.namespace
  stage                    = var.stage
  bucket_name              = "${var.namespace}-${var.stage}"
  parent_zone_name         = var.parent_zone_name
  aliases                  = ["www.thepragmaticloud.com", "thepragmaticloud.com"]
  origin_id                = "${var.namespace}-${var.stage}-origin-id"
  origin_force_destroy     = true
  acm_certificate_arn      = var.acm_certificate_arn
  minimum_protocol_version = var.minimum_protocol_version
  tags                     = module.labels.tags
}