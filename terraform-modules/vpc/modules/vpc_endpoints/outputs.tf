output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint"
  value       = var.enabled ? aws_vpc_endpoint.s3[0].id : null
}

output "interface_endpoint_ids" {
  description = "Map of interface endpoint IDs keyed by service short name"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}
