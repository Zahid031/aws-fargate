# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true  # required for VPC interface endpoints to resolve
  enable_dns_hostnames = true  # required for VPC interface endpoints to resolve

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# Internet Gateway — gives public subnets a route to/from the internet
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}
