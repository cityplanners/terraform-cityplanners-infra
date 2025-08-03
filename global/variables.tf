variable "atlas_public_key" {
  description = "MongoDB Atlas public key for API access"
  type        = string
  sensitive   = true
}

variable "atlas_private_key" {
  description = "MongoDB Atlas private key for API access"
  type        = string
  sensitive   = true
}

variable "atlas_project_id" {
  description = "MongoDB Atlas project ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type = string
}

variable "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
  type = string
}
