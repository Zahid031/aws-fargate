resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-${var.sg_name}-sg"
  description = var.sg_description
  vpc_id      = var.vpc_id

  # Supports two ingress source types:
  #   cidr_blocks              — for rules that allow a CIDR range (e.g. 0.0.0.0/0 for ALB)
  #   source_security_group_id — for rules that allow only a specific SG (e.g. ALB → app)
  # Exactly one of the two must be set per rule.
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = ingress.value.cidr_blocks != null ? ingress.value.cidr_blocks : []
      security_groups = ingress.value.source_security_group_id != null ? [ingress.value.source_security_group_id] : []
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.sg_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
