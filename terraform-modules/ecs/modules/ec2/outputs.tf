output "bastion_private_ip" {
  description = "Private IP of the bastion host"
  value       = aws_instance.bastion.private_ip
}

output "postgres_private_ip" {
  description = "Private IP of the postgres instance"
  value       = aws_instance.postgres.private_ip
}

output "postgres_sg_id" {
  description = "Security Group ID of the postgres instance"
  value       = aws_security_group.postgres.id
}
