# locals {
#   database_url = "postgresql+psycopg://${var.db_user}:${var.db_password}@${aws_instance.postgres.private_ip}:5432/${var.db_name}"
# }