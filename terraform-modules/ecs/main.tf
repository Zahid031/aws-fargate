# -----------------------------------------------------------------------------
# VPC Remote State
# Reads outputs from the VPC Terraform layer so we don't hardcode any IDs.
# This is the standard way to share state across Terraform root modules.
# -----------------------------------------------------------------------------
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.vpc_state_bucket
    key    = var.vpc_state_key
    region = var.aws_region
  }
}

locals {
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids   = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  private_subnet_ids  = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  sg_alb_id           = data.terraform_remote_state.vpc.outputs.sg_alb_id
  sg_app_id           = data.terraform_remote_state.vpc.outputs.sg_app_id
}

# -----------------------------------------------------------------------------
# ECR Repository
# Stores the FastAPI container image. CI/CD pushes here; Fargate pulls from here.
# image_tag_mutability = MUTABLE so CI/CD can overwrite the "latest" tag.
# scan_on_push catches known CVEs at build time for free.
# -----------------------------------------------------------------------------
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# IAM Roles
# Two distinct roles — a common mistake is to merge them into one:
#
# execution_role — used by the ECS CONTROL PLANE (not your code) to:
#   - Pull the image from ECR
#   - Write logs to CloudWatch (task startup logs)
#   - Read secrets from SSM/Secrets Manager (if added later)
#
# task_role — assumed by your RUNNING CONTAINER CODE to:
#   - Write traces to X-Ray
#   - Write logs to CloudWatch (ADOT sidecar)
#   - Pull ECR auth token (ADOT pulls its own config)
# -----------------------------------------------------------------------------
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  ecr_arn      = module.ecr.repository_arn
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# ADOT sidecar ships logs here. Separate log groups per layer makes
# CloudWatch Logs Insights queries simpler and permission scoping cleaner.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/ecs/${var.project_name}-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "adot" {
  name              = "/ecs/${var.project_name}-${var.environment}/adot"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/ecs/${var.project_name}-${var.environment}/adot"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# HTTP only (port 80) for this assessment.
# Sits in public subnets, forwards to Fargate tasks in private subnets.
# -----------------------------------------------------------------------------
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids
  sg_alb_id         = local.sg_alb_id
  app_port          = var.app_port
  health_check_path = var.health_check_path
}

# -----------------------------------------------------------------------------
# ECS Cluster + Task Definition + Service
# -----------------------------------------------------------------------------
module "ecs" {
  source       = "./modules/ecs"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Networking
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  sg_app_id          = local.sg_app_id

  # Image
  ecr_repository_url = module.ecr.repository_url
  app_image_tag      = var.app_image_tag
  app_port           = var.app_port

  # Compute
  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count

  # IAM
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn

  # ALB
  target_group_arn = module.alb.target_group_arn

  # Observability
  log_group_app  = aws_cloudwatch_log_group.app.name
  log_group_adot = aws_cloudwatch_log_group.adot.name
  database_url   = var.database_url
}

# -----------------------------------------------------------------------------
# EC2 Instances (Bastion + Postgres)
# -----------------------------------------------------------------------------
module "ec2" {
  source             = "./modules/ec2"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
}








