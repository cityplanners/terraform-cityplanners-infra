module "global" {
  source = "../global"
}

resource "aws_s3_bucket" "frontend" {
  bucket = var.client_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

data "aws_secretsmanager_secret_version" "client_db_pass" {
  secret_id = "cityplanners/${var.client_name}/mongodb-password"
}

locals {
  client_db_password = jsondecode(data.aws_secretsmanager_secret_version.client_db_pass.secret_string)["password"]
}

data "aws_secretsmanager_secret_version" "atlas_project_id" {
  secret_id = "/global/mongodb_atlas_project_id"
}

locals {
  mongodb_uri = var.use_payload ? "mongodb+srv://${var.client_db_user}:${local.client_db_password}@${module.global.atlas_cluster_connection_strings.standard_srv}/${var.client_name}" : null
}

# MongoDB User
resource "mongodbatlas_database_user" "payload_user" {
  count              = var.use_payload ? 1 : 0
  username           = "payload-${var.client_name}"
  password           = local.client_db_password
  project_id         = var.atlas_project_id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.client_name
  }

  scopes {
    name = var.atlas_cluster_name
    type = "CLUSTER"
  }
}

# S3 Bucket for Nuxt frontend
resource "aws_s3_bucket" "frontend" {
  bucket = var.client_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  tags = {
    Name        = "${var.client_name}-nuxt-frontend"
    Environment = "production"
  }
}

# ECS + Fargate Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.client_name}-cluster"
}

# Security group
resource "aws_security_group" "payload_sg" {
  name   = "${var.client_name}-payload-sg"
  vpc_id = module.global.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fargate task definition
resource "aws_ecs_task_definition" "payload" {
  family                   = "${var.client_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

  container_definitions = jsonencode([
    for c in var.containers : merge(
      {
        name  = c.name
        image = c.image
        portMappings = [{
          containerPort = c.port
          hostPort      = c.port
        }]
        environment = [
          for k, v in c.environment : {
            name  = k
            value = v
          }
        ]
        secrets = [
          for k, v in c.secrets : {
            name      = k
            valueFrom = v
          }
        ]
      }
    )
  ])
}

# ECS service
resource "aws_ecs_service" "payload" {
  count           = var.use_payload ? 1 : 0
  name            = "${var.client_name}-payload-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payload.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = module.global.subnet_ids
    security_groups = [aws_security_group.payload_sg.id]
    assign_public_ip = true
  }
}

# Load balancer (for external access to Payload)
resource "aws_lb" "payload_lb" {
  name               = "${var.client_name}-lb"
  internal           = false
  subnets            = module.global.subnet_ids
}

# ACM Certificate
resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  count                     = var.domain_registered_in_aws ? 1 : 0
  certificate_arn           = aws_acm_certificate.cert.arn
  validation_record_fqdns   = [aws_route53_record.cert_validation[0].fqdn]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "s3-origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.client_name} CDN"
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.cert.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  aliases = [
    var.domain_name,
    "cms.${var.domain_name}"
  ]
}

resource "aws_route53_record" "cert_validation" {
  count   = var.domain_registered_in_aws ? 1 : 0
  name    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_type
  zone_id = var.route53_zone_id
  records = [aws_acm_certificate.cert.domain_validation_options[0].resource_record_value]
  ttl     = 60
}

# Route53 Alias Record
resource "aws_route53_record" "alias" {
  count   = var.domain_registered_in_aws ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# Register cms subdomain
resource "aws_route53_record" "cms_subdomain" {
  count   = var.use_payload && var.domain_registered_in_aws ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "cms.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.payload.domain_name
    zone_id                = aws_cloudfront_distribution.payload.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "wildcard_cert" {
  domain_name               = "*.${var.domain_name}"
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.client_name}-wildcard-cert"
  }
}

resource "aws_route53_record" "wildcard_cert_validation" {
  count   = var.domain_registered_in_aws ? 1 : 0
  name    = tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_type
  zone_id = var.route53_zone_id
  records = [tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  count                    = var.domain_registered_in_aws ? 1 : 0
  certificate_arn          = aws_acm_certificate.wildcard_cert.arn
  validation_record_fqdns  = [aws_route53_record.wildcard_cert_validation[0].fqdn]
}
