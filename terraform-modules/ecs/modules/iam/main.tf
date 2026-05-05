locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role
# Assumed by the ECS AGENT (control plane), not your application code.
# Grants the agent permission to pull the image and write startup logs.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# AWS managed policy — covers ECR pull + CloudWatch Logs for startup logs.
# No need to write custom policy here; this managed policy is exactly scoped
# for ECS execution needs and is maintained by AWS.
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# ECS Task Role
# Assumed by YOUR APPLICATION CODE at runtime (both app and ADOT containers).
# Grants only what the running containers actually need.
# Principle of least privilege: no * actions, no * resources.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "task_policy" {
  name = "${local.name_prefix}-ecs-task-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ── X-Ray (ADOT sidecar exports traces here) ──────────────────────────
      {
        Sid    = "XRayWrite"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",     # upload completed trace segments
          "xray:PutTelemetryRecords",  # upload collector health metrics
          "xray:GetSamplingRules",     # read dynamic sampling rules
          "xray:GetSamplingTargets",   # read sampling targets
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*" # X-Ray does not support resource-level restrictions
      },
      # ── CloudWatch Logs (ADOT sidecar ships app logs here) ────────────────
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}-${var.environment}*:*"
      },
      # ── ECR (ADOT pulls its own collector image at startup) ────────────────
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*" # GetAuthorizationToken does not support resource restriction
      },
      {
        Sid    = "ECRImagePull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.ecr_arn
      }
    ]
  })
}
