# -----------------------------------------------------------------------------
# Outputs — referenced by CI/CD pipeline and README deploy guide
# -----------------------------------------------------------------------------
output "ecr_repository_url" {
  description = "ECR repository URL — used in docker push commands"
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name — the public URL of the application"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used by CI/CD force-new-deployment"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name — used by CI/CD force-new-deployment"
  value       = module.ecs.service_name
}

output "cloudwatch_log_group_app" {
  description = "CloudWatch log group for the FastAPI app"
  value       = aws_cloudwatch_log_group.app.name
}

output "cloudwatch_log_group_adot" {
  description = "CloudWatch log group for the ADOT sidecar"
  value       = aws_cloudwatch_log_group.adot.name
}

output "bastion_private_ip" {
  description = "Private IP of the bastion host"
  value       = module.ec2.bastion_private_ip
}

output "postgres_private_ip" {
  description = "Private IP of the postgres instance"
  value       = module.ec2.postgres_private_ip
}
