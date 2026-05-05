# General
variable "aws_region" {
  description = "AWS region — must be us-east-1 or eu-west-1 per assessment rules"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name — used as a prefix for all resource names"
  type        = string
  default     = "fastapi-fargate"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "prod"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Two AZs is enough for HA; three would require a second NAT Gateway
# which costs ~$32/month — outside the free-tier budget.
variable "availability_zones" {
  description = "List of AZs — must match the number of subnet CIDR entries"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB lives here)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (Fargate tasks live here)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private-subnet egress"
  type        = bool
  default     = true
}

# Always true for this project — one NAT Gateway keeps us in free-tier budget.
# The risk: if us-east-1a goes down, tasks in us-east-1b lose outbound access.
# Acceptable trade-off for a cost-constrained assessment.
variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ (cost saving)"
  type        = bool
  default     = true
}

# VPC Endpoints
# Interface endpoints eliminate NAT data-transfer charges for AWS API calls
# (ECR auth, ECR image layers via S3, CloudWatch Logs, X-Ray).
# Each interface endpoint costs ~$0.01/hr (~$7/month) — for a short-lived
# assessment deployment this is negligible, and the saving on NAT data
# transfer is real once image pulls start.
variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints for ECR, S3, CloudWatch Logs, and X-Ray"
  type        = bool
  default     = true
}
