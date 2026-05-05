locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Number of NAT Gateways:
  #   enable_nat_gateway = false → 0
  #   enable_nat_gateway = true, single_nat_gateway = true  → 1
  #   enable_nat_gateway = true, single_nat_gateway = false → one per AZ
  nat_gw_count = var.enable_nat_gateway ? (
    var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)
  ) : 0
}
