# Mongo Atlas (shared)
variable "aws_region" {
  description = "AWS region to deploy to"
  default     = "us-east-1"
}

variable "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
}

# Client-specific
variable "client_name" {
  description = "Prefix for resource naming"
}

variable "client_db_password" {
  default = jsondecode(data.aws_secretsmanager_secret_version.client_db_pass.secret_string)["password"]
  description = "Password for the MongoDB database user"
  sensitive   = true
}

variable "use_payload" {
  description = "Whether to provision Payload CMS and MongoDB resources"
  type        = bool
  default     = false
}

variable "payload_container_image" {
  description = "Docker image for Payload CMS"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for Nuxt static hosting"
}

variable "containers" {
  description = "List of container configurations for this ECS task"
  type = list(object({
    name         = string
    image        = string
    port         = number
    environment  = optional(map(string))
  }))
}

variable "domain_name" {
  description = "The client's custom domain"
}

variable "domain_registered_in_aws" {
  description = "Whether the domain is registered in Route 53"
  type        = bool
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID (required if domain_registered_in_aws is true)"
  type        = string
  default     = ""
}
