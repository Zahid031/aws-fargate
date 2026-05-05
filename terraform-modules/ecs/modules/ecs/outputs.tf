output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "ECS service name  used by CI/CD force-new-deployment"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN of the latest task definition revision"
  value       = aws_ecs_task_definition.this.arn
}
