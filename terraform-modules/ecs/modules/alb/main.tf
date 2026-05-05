locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# Internal = false means it gets a public DNS name reachable from the internet.
# The ALB itself has no public IP — traffic comes in via the IGW to its nodes
# in the public subnets.
# -----------------------------------------------------------------------------
resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.public_subnet_ids

  # Deletion protection off — allows terraform destroy to clean up cleanly.
  # In a real production environment this would be true.
  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# -----------------------------------------------------------------------------
# Target Group
# Fargate tasks register themselves here when the service starts.
# deregistration_delay: reduced to 30s (default 300s) so deployments drain
# quickly — important for a 2-task setup where rolling updates are noticeable.
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  name        = "${local.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate (tasks have IPs, not instance IDs)

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    healthy_threshold   = 2   # 2 consecutive 200s = healthy
    unhealthy_threshold = 3   # 3 consecutive failures = unhealthy
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

# -----------------------------------------------------------------------------
# HTTP Listener — port 80
# For the assessment HTTP is fine. If you add ACM later, add an HTTPS listener
# and redirect this one: aws_lb_listener_rule with redirect action.
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
