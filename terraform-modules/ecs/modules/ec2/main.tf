locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# AMI Lookup
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# -----------------------------------------------------------------------------
# IAM Role for SSM (Systems Manager)
# Allows connecting to instances in private subnets without a jump box/SSH.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ssm_role" {
  name = "${local.name_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${local.name_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# Bastion SG
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-bastion-sg"
  }
}

# Postgres SG
resource "aws_security_group" "postgres" {
  name        = "${local.name_prefix}-postgres-sg"
  description = "Security group for Postgres instance"
  vpc_id      = var.vpc_id

  # Allow inbound from Bastion
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  
  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = ["sg-0355e848e370310c4"]
  }

  # Allow outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-postgres-sg"
  }
}

# -----------------------------------------------------------------------------
# EC2 Instances
# -----------------------------------------------------------------------------

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "${local.name_prefix}-bastion"
  }
}

# Postgres Instance
resource "aws_instance" "postgres" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.postgres.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash

              dnf update -y

              # Install Docker
              dnf install -y docker

              # Start & enable Docker
              systemctl enable docker
              systemctl start docker

              # Allow ec2-user to use Docker
              usermod -aG docker ec2-user
              EOF


  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
