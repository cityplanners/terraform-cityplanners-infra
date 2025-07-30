variable "atlas_project_id" {
  description = "MongoDB Atlas project ID"
  type        = string
}

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
}

variable "vpc_id" {
  description = "VPC ID to attach resources to"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnets for Fargate and ALB"
  type        = list(string)
}

variable "mongodb_uri" {
  description = "Connection URI to MongoDB Atlas"
  type        = string
}

variable "client_db_user" {
  type = string
  description = "The MongoDB user to create for this client"
}

variable "atlas_cluster_connection_strings" {
  type = string
  description = "Atlas SRV connection string prefix"
}

variable "payload_secret" {
  description = "Secret for Payload CMS signing"
  type        = string
}

variable "atlas_cluster_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
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
