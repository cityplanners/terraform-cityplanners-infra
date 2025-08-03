terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15.0"
    }
  }
}

data "aws_ssm_parameter" "atlas_project_id" {
  name            = "/global/mongodb_atlas_project_id"
  with_decryption = true
}

data "aws_ssm_parameter" "atlas_private_key" {
  name            = "/global/mongodb_atlas_private_key"
  with_decryption = true
}

data "aws_ssm_parameter" "atlas_public_key" {
  name            = "/global/mongodb_atlas_public_key"
  with_decryption = true
}

data "aws_ssm_parameter" "mongodb_uri" {
  name            = "/clients/${var.client_name}/mongodb_uri"
  with_decryption = true
}

data "aws_ssm_parameter" "payload_secret" {
  name            = "/clients/${var.client_name}/payload_secret"
  with_decryption = true
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "mongodbatlas" {
  public_key  = data.aws_ssm_parameter.atlas_public_key.value
  private_key = data.aws_ssm_parameter.atlas_private_key.value
}

module "global" {
  source = "./global"

  providers = {
    mongodbatlas = mongodbatlas
  }

  aws_region         = var.aws_region
  atlas_cluster_name = var.atlas_cluster_name
  atlas_project_id   = data.aws_ssm_parameter.atlas_project_id.value
  atlas_private_key  = data.aws_ssm_parameter.atlas_private_key.value
  atlas_public_key   = data.aws_ssm_parameter.atlas_public_key.value
}

module "client_instance" {
  source = "./instance"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  atlas_project_id  = data.aws_ssm_parameter.atlas_project_id.value

  client_name              = var.client_name
  domain_name              = var.domain_name
  domain_registered_in_aws = var.domain_registered_in_aws
  use_payload              = var.use_payload

  # Extract just the hostname from the full connection string
  atlas_cluster_connection_string = regex("mongodb\\+srv://([^/?]+)", module.global.atlas_cluster_connection_string)[0]

  client_db_user = "payload-${var.client_name}"
  atlas_cluster_name       = var.atlas_cluster_name
  route53_zone_id          = var.route53_zone_id

  vpc_id         = module.global.vpc_id
  subnet_ids     = module.global.subnet_ids

  mongodb_uri    = data.aws_ssm_parameter.mongodb_uri.value
  payload_secret = data.aws_ssm_parameter.payload_secret.value

  containers = var.containers
}
