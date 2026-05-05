output "repository_url" {
  description = "Full ECR repository URL (used in docker push and task definition)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN (used to scope IAM permissions)"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.this.name
}
