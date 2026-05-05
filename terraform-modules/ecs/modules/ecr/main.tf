resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE" # CI/CD overwrites "latest" on every push

  image_scanning_configuration {
    scan_on_push = true # free CVE scan at build time
  }

  # Prevent accidental deletion of the repo (and all images) with terraform destroy.
  # Set to false only when you intentionally want to tear everything down.
  force_delete = false

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# Lifecycle Policy — keep only the 10 most recent images.
# Without this, every CI push accumulates images indefinitely.
# ECR charges $0.10/GB-month after the free tier; pruning keeps it near zero.
# -----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
