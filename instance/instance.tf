terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }

    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15.0"
    }
  }
}

data "aws_ssm_parameter" "client_db_pass" {
  name = "/clients/${var.client_name}/mongodb-password"
  with_decryption = true
}

data "aws_ssm_parameter" "atlas_project_id" {
  name = "/global/mongodb_atlas_project_id"
  with_decryption = true
}

locals {
  client_db_password = data.aws_ssm_parameter.client_db_pass.value
  mongodb_uri = var.use_payload ? "mongodb+srv://${var.client_db_user}:${local.client_db_password}@${var.atlas_cluster_connection_string}/${var.client_name}" : null
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
  tags = {
    Name        = "${var.client_name}-nuxt-frontend"
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadGetObject",
      Effect    = "Allow",
      Principal = "*",
      Action    = ["s3:GetObject"],
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

# ECS + Fargate Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.client_name}-cluster"
}

# Security group for ALB (separate from ECS security group)
resource "aws_security_group" "alb_sg" {
  name   = "${var.client_name}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.client_name}-alb-sg"
  }
}

# Security group
resource "aws_security_group" "payload_sg" {
  name   = "${var.client_name}-payload-sg"
  vpc_id = var.vpc_id

  # Only allow traffic from the ALB security group (more secure)
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS task execution IAM role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.client_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Fargate task definition
resource "aws_ecs_task_definition" "payload" {
  family                   = "${var.client_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

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
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.payload_sg.id]
    assign_public_ip = true
  }

  # Add this load_balancer block
  load_balancer {
    target_group_arn = aws_lb_target_group.payload_tg[0].arn
    container_name   = "payload"  # This should match the container name in your task definition
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.payload_https]
}

# Target group for ECS tasks
resource "aws_lb_target_group" "payload_tg" {
  count       = var.use_payload ? 1 : 0
  name        = "${var.client_name}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Important for Fargate

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"  # Adjust if Payload has a different health check path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.client_name}-tg"
  }
}

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "payload_http" {
  count             = var.use_payload ? 1 : 0
  load_balancer_arn = aws_lb.payload_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "payload_https" {
  count             = var.use_payload ? 1 : 0
  load_balancer_arn = aws_lb.payload_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payload_tg[0].arn
  }
}

# Load balancer (for external access to Payload)
resource "aws_lb" "payload_lb" {
  name               = "${var.client_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids
  
  enable_deletion_protection = false

  tags = {
    Name = "${var.client_name}-alb"
  }
}

# ACM Certificate
resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  validation_method         = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"       # Covers all subdomains including cms.yourdomain.com
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  provider                  = aws.us_east_1
  count                     = var.domain_registered_in_aws ? 1 : 0
  certificate_arn           = aws_acm_certificate.cert.arn
  validation_record_fqdns   = [aws_route53_record.cert_validation[0].fqdn]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  provider      = aws.us_east_1

  # S3 origin for main site
  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = "s3-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ALB origin for CMS (only if using Payload)
  dynamic "origin" {
    for_each = var.use_payload ? [1] : []
    content {
      domain_name = aws_lb.payload_lb.dns_name
      origin_id   = "alb-origin"
      
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.client_name} CDN"
  default_root_object = "index.html"

  # Default behavior - serve from S3
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

  # CMS behavior - route cms.* requests to ALB
  dynamic "ordered_cache_behavior" {
    for_each = var.use_payload ? [1] : []
    content {
      path_pattern     = "/cms*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "alb-origin"

      forwarded_values {
        query_string = true
        headers      = ["*"]
        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
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
  provider = aws.us_east_1
  
  for_each = var.domain_registered_in_aws ? {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
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
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "wildcard_cert" {
  provider                  = aws.us_east_1
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
  provider= aws.us_east_1
  count   = var.domain_registered_in_aws ? 1 : 0
  name    = tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_type
  zone_id = var.route53_zone_id
  records = [tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  provider                 = aws.us_east_1
  count                    = var.domain_registered_in_aws ? 1 : 0
  certificate_arn          = aws_acm_certificate.wildcard_cert.arn
  validation_record_fqdns  = [aws_route53_record.wildcard_cert_validation[0].fqdn]
}
