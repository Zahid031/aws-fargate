# VPC
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

# Subnets
output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (Fargate tasks)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = module.vpc.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = module.vpc.private_subnet_cidrs
}

# Gateways
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "ID(s) of the NAT Gateway(s)"
  value       = module.vpc.nat_gateway_ids
}

output "nat_public_ips" {
  description = "Public Elastic IP(s) of the NAT Gateway(s)"
  value       = module.vpc.nat_public_ips
}

# Security Groups
# — exported so the ECS / ALB Terraform modules can reference them
output "sg_alb_id" {
  description = "Security Group ID for the ALB"
  value       = module.sg_alb.security_group_id
}

output "sg_app_id" {
  description = "Security Group ID for Fargate tasks"
  value       = module.sg_app.security_group_id
}

output "sg_endpoint_id" {
  description = "Security Group ID for VPC interface endpoints"
  value       = module.sg_endpoint.security_group_id
}
