output "s3_bucket_url" {
  value = "https://${var.s3_bucket_name}.s3.amazonaws.com"
}

output "payload_service_url" {
  value = aws_lb.payload_lb.dns_name
}

output "payload_lb_dns_name" {
  value       = var.use_payload ? aws_lb.payload_lb.dns_name : null
  description = "DNS name of the load balancer for accessing Payload"
}

output "cert_dns_validation" {
  value = aws_acm_certificate.cert.domain_validation_options
  description = "Manually add these DNS records to your registrar for ACM to validate the domain"
  condition   = !var.domain_registered_in_aws
}

output "payload_lb_dns" {
  value       = var.use_payload ? aws_lb.payload_lb.dns_name : null
  description = "DNS name of the load balancer for accessing the Payload CMS"
}

output "ecs_service_name" {
  value       = var.use_payload ? aws_ecs_service.payload.name : null
  description = "ECS service name"
}

output "ecs_task_definition_arn" {
  value       = var.use_payload ? aws_ecs_task_definition.payload.arn : null
  description = "ECS task definition ARN"
}

output "cms_subdomain_dns_instructions" {
  description = "Instructions if domain is NOT registered in Route 53"
  value = var.domain_registered_in_aws ? null : "Please add a CNAME record for cms.${var.domain_name} pointing to ${aws_cloudfront_distribution.site.domain_name}"
}
