# Public Subnets — one per AZ
# ALB lives here. map_public_ip_on_launch is true so the ALB nodes get
# public IPs and can accept inbound traffic from the internet.
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Tier = "public"
  }
}

# Private Subnets — one per AZ
# Fargate tasks live here. No public IPs; outbound traffic goes via NAT GW.
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    Tier = "private"
  }
}
