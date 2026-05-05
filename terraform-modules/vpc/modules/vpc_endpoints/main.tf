locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# S3 Gateway Endpoint (FREE — no hourly charge)
# ECR stores image layers in S3. Without this, every docker pull from ECR
# sends image layer data through the NAT Gateway → public internet → back in.
# With this gateway endpoint, that traffic stays on the AWS backbone at no cost.
# Must be associated with private route tables (gateway endpoints work via BGP
# route injection, not DNS).
resource "aws_vpc_endpoint" "s3" {
  count = var.enabled ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    Name = "${local.name_prefix}-endpoint-s3"
  }
}

# Interface Endpoints (~$0.01/hr each)
# These create private DNS entries so AWS SDK calls resolve to private IPs
# inside your VPC, bypassing the NAT Gateway entirely.
#
# ecr.api  — ECR GetAuthorizationToken + DescribeRepositories
# ecr.dkr  — ECR image manifest + layer pull (works with S3 gateway above)
# logs     — CloudWatch Logs PutLogEvents (ADOT sidecar)
# xray     — X-Ray PutTraceSegments (ADOT sidecar)
locals {
  interface_endpoints = var.enabled ? {
    "ecr-api" = "com.amazonaws.${var.aws_region}.ecr.api"
    "ecr-dkr" = "com.amazonaws.${var.aws_region}.ecr.dkr"
    "logs"    = "com.amazonaws.${var.aws_region}.logs"
    "xray"    = "com.amazonaws.${var.aws_region}.xray"
  } : {}
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.endpoint_sg_id]

  # Private DNS replaces the public endpoint hostname with a private one.
  # This means existing SDK/ADOT config needs no changes — the DNS resolution
  # just returns a private IP automatically.
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-endpoint-${each.key}"
  }
}
