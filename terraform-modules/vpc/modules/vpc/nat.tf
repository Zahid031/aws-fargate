# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = local.nat_gw_count
  domain = "vpc"

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${local.name_prefix}-eip-nat-${count.index + 1}"
  }
}

# NAT Gateways — placed in public subnets, used by private subnets
#
# single_nat_gateway = true  → one shared NAT in public-subnet-1 (cost saving)
# single_nat_gateway = false → one NAT per AZ (HA, ~$32/mo per extra gateway)
#
# For this assessment we use single_nat_gateway = true.
# The NAT Gateway is only needed for:
#   - ECR auth token endpoint (if VPC endpoints are disabled)
#   - Any third-party outbound calls from the app
# With VPC endpoints enabled, most AWS API traffic bypasses the NAT entirely.
resource "aws_nat_gateway" "this" {
  count = local.nat_gw_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  }
}
