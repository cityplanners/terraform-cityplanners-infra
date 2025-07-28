terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.14.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_secretsmanager_secret_version" "atlas_public_key" {
  secret_id = "/global/mongodb_atlas_public_key"
}

data "aws_secretsmanager_secret_version" "atlas_private_key" {
  secret_id = "/global/mongodb_atlas_private_key"
}

data "aws_secretsmanager_secret_version" "atlas_project_id" {
  secret_id = "/global/mongodb_atlas_project_id"
}

provider "aws" {
  region = var.aws_region
}

provider "mongodbatlas" {
  public_key  = data.aws_secretsmanager_secret_version.atlas_public_key.secret_string
  private_key = data.aws_secretsmanager_secret_version.atlas_private_key.secret_string
}

variable "atlas_project_id" {
  type = string
  description = "MongoDB Atlas project ID"
  default = data.aws_secretsmanager_secret_version.atlas_project_id.secret_string
}

# VPC
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cityplanners-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "cityplanners-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# MongoDB cluster
resource "mongodbatlas_cluster" "main" {
  project_id                    = var.atlas_project_id
  name                          = var.atlas_cluster_name

  provider_name                 = "AWS"
  region_name                   = "US_EAST_1"

  cluster_type                  = "REPLICASET"
  backing_provider_name         = "AWS"
  provider_instance_size_name   = "M0" # Free tier (shared cluster)

  auto_scaling_disk_gb_enabled  = true
  disk_size_gb                  = 2

  provider_backup_enabled       = false
}
