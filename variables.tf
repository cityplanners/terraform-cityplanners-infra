# Mongo Atlas (shared)
variable "aws_region" {
  description = "AWS region to deploy to"
  default     = "us-east-1"
}

variable "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
  type = string
}

# Client-specific
variable "client_name" {
  description = "Prefix for naming resources"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name"
  type        = string
}

variable "domain_registered_in_aws" {
  description = "Whether the domain is managed in Route 53"
  type        = bool
}

variable "use_payload" {
  description = "Whether to provision Payload CMS"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID (required if domain_registered_in_aws is true)"
  type        = string
  default     = ""
}

variable "containers" {
  description = "Container definitions for ECS"
  type = list(object({
    name        = string
    image       = string
    port        = number
    environment = optional(map(string))
    secrets     = optional(map(string))
  }))
}
