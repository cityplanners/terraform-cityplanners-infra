variable "aws_region" {
  description = "AWS region to deploy to"
  default     = "us-east-1"
}

variable "atlas_public_key" {
  sensitive   = true
}

variable "atlas_private_key" {
  sensitive   = true
}

variable "atlas_project_id" {
  description = "MongoDB Atlas Project ID"
  sensitive   = true
}

variable "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name"
}
