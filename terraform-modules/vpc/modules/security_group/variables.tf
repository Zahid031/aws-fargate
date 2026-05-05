variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to create the security group in"
  type        = string
}

variable "sg_name" {
  description = "Short name for the security group (e.g. alb, app, endpoint)"
  type        = string
}

variable "sg_description" {
  description = "Human-readable description of the security group"
  type        = string
  default     = "Managed by Terraform"
}

# KEY ADDITION vs original:
# The original only supported cidr_blocks as an ingress source.
# This version adds source_security_group_id so the app SG can restrict
# inbound traffic to the ALB SG rather than the broad VPC CIDR.
# Exactly one of cidr_blocks or source_security_group_id must be non-null.
variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  # Allow all outbound by default — tasks need to reach AWS endpoints
  # (ECR, CloudWatch, X-Ray) via VPC endpoints or NAT Gateway.
  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
