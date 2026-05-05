variable "project_name" { type = string }
variable "environment"  { type = string }
variable "aws_region"   { type = string }
variable "ecr_arn" {
  description = "ECR repository ARN — scopes the image-pull IAM permission"
  type        = string
}
