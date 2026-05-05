# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resource names"
  type        = string
  default     = "fastapi-fargate"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# VPC remote state
# Points to the S3 backend of the VPC layer so we can read its outputs
# (vpc_id, subnet IDs, security group IDs) without copy-pasting values.
# -----------------------------------------------------------------------------
variable "vpc_state_bucket" {
  description = "S3 bucket holding the VPC layer's Terraform state"
  type        = string
}

variable "vpc_state_key" {
  description = "S3 key for the VPC layer state file"
  type        = string
  default     = "prod/vpc/terraform.tfstate"
}

# -----------------------------------------------------------------------------
# Application
# -----------------------------------------------------------------------------
variable "app_port" {
  description = "Port the FastAPI container listens on"
  type        = number
  default     = 8000
}

variable "app_image_tag" {
  description = "ECR image tag to deploy — overridden by CI/CD on each push"
  type        = string
  default     = "latest"
}

# Fargate task CPU/memory — 256 CPU + 512 MB is the smallest valid combination.
# Stays within the 12-month free tier (750 hrs/month for vCPU + GB-hrs).
variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}

# -----------------------------------------------------------------------------
# ECS Service
# -----------------------------------------------------------------------------
variable "desired_count" {
  description = "Number of Fargate tasks to run (2 for HA across both AZs)"
  type        = number
  default     = 2
}

variable "health_check_path" {
  description = "ALB health check path  must return HTTP 200"
  type        = string
  default     = "/health"
}

# -----------------------------------------------------------------------------
# Observability
# -----------------------------------------------------------------------------
variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7 # short retention keeps costs low for the assessment
}

variable "database_url" {
  description = "URL for the PostgreSQL database"
  type        = string
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "postgres-password"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "hero_db"
}