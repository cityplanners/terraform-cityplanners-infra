data "aws_secretsmanager_secret_version" "atlas_project_id" {
  secret_id = "/global/mongodb_atlas_project_id"
}

module "global" {
  source = "./global"

  atlas_public_key  = var.atlas_public_key
  atlas_private_key = var.atlas_private_key
  atlas_project_id  = data.aws_secretsmanager_secret_version.atlas_project_id.secret_string
}

module "client_instance" {
  source = "./instances"

  atlas_project_id  = data.aws_secretsmanager_secret_version.atlas_project_id.secret_string

  client_name              = var.client_name
  domain_name              = var.domain_name
  domain_registered_in_aws = var.domain_registered_in_aws
  use_payload              = var.use_payload

  vpc_id     = module.global.vpc_id
  subnets    = module.global.private_subnets

  mongodb_uri     = var.mongodb_uri
  payload_secret  = var.payload_secret
}
