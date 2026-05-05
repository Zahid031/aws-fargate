# VPC — subnets, IGW, NAT, route tables
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
}

# Security Group — Application Load Balancer
# Accepts HTTPS from the internet; HTTP is redirected to HTTPS at the listener
module "sg_alb" {
  source         = "./modules/security_group"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  sg_name        = "alb"
  sg_description = "ALB  HTTPS inbound from internet"

  ingress_rules = [
    {
      description              = "HTTPS from internet"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      cidr_blocks              = ["0.0.0.0/0"]
      source_security_group_id = null
    },
    {
      description              = "HTTP from internet (redirected to HTTPS at listener)"
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      cidr_blocks              = ["0.0.0.0/0"]
      source_security_group_id = null
    },
  ]
}

# Security Group — Fargate Tasks (FastAPI app)
# KEY FIX vs original:
#   Original used cidr_blocks = [var.vpc_cidr] (allows anything in the VPC).
#   Correct approach: allow port 8000 ONLY from the ALB security group

module "sg_app" {
  source         = "./modules/security_group"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  sg_name        = "app"
  sg_description = "Fargate tasks  inbound only from ALB SG on port 8000"

  ingress_rules = [
    {
      description              = "FastAPI port from ALB only"
      from_port                = 8000
      to_port                  = 8000
      protocol                 = "tcp"
      cidr_blocks              = null # source is a SG, not a CIDR
      source_security_group_id = module.sg_alb.security_group_id
    },
  ]
}

# VPC Endpoints
# Without these, every ECR image pull, CloudWatch Logs write, and X-Ray put
# leaves the VPC through the NAT Gateway and back in through the AWS public
# endpoint — costing NAT data-transfer fees and adding latency.
# With endpoints, that traffic stays on the AWS backbone (free).
#
# Gateway endpoint — S3 (free, no hourly charge)
#   ECR stores image layers in S3; this covers the bulk of image-pull traffic.
#
# Interface endpoints — charged at ~$0.01/hr each:
#   ecr.api   — ECR auth + manifest fetch
#   ecr.dkr   — ECR image layer pulls (works together with S3 gateway)
#   logs      — CloudWatch Logs (used by ADOT sidecar)
#   xray      — AWS X-Ray (used by ADOT sidecar)
module "vpc_endpoints" {
  source               = "./modules/vpc_endpoints"
  enabled              = var.enable_vpc_endpoints
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  aws_region           = var.aws_region
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_route_table_ids = module.vpc.private_route_table_ids
  endpoint_sg_id       = module.sg_endpoint.security_group_id
}

# Security Group — VPC Interface Endpoints
# Fargate tasks (and anything in the VPC) must be able to reach the endpoints
# on HTTPS (443). Source is the app SG — only the tasks need endpoint access.
module "sg_endpoint" {
  source         = "./modules/security_group"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  sg_name        = "endpoint"
  sg_description = "VPC interface endpoints  HTTPS from app tasks"

  ingress_rules = [
    {
      description              = "HTTPS from Fargate tasks"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      cidr_blocks              = null
      source_security_group_id = module.sg_app.security_group_id
    },
  ]
}
