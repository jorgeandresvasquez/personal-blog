variable "stage" {
  description = "The stage or environment name"
  type        = string
}

variable "parent_zone_name" {
  description = "The name of the parent zone in route53"
  type        = string
}

variable "namespace" {
  description = "Namespace to which these resources are associated"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol supported"
  type        = string
  default     = "TLSv1.2"
}

variable "hostname" {
  type        = string
  description = "Name of website bucket in `fqdn` format (e.g. `test.example.com`). IMPORTANT! Do not add trailing dot (`.`)"
}