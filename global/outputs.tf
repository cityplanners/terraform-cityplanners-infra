output "atlas_cluster_id" {
  value = mongodbatlas_cluster.main.id
}

output "atlas_cluster_connection_string" {
  description = "The MongoDB Atlas SRV connection string for Payload"
  value       = mongodbatlas_cluster.main.connection_strings[0].standard_srv
  sensitive   = true
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "region" {
  value = var.aws_region
}
