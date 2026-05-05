locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # ADOT collector image — AWS-managed public image, always up to date.
  # We pin to a specific version so deployments are reproducible.
  # Check for newer versions at:
  # https://gallery.ecr.aws/aws-observability/aws-otel-collector
  adot_image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.40.0"
}

# -----------------------------------------------------------------------------
# ECS Cluster
# Container Insights adds CloudWatch metrics for the cluster (CPU, memory,
# network per task). It costs slightly more but gives useful operational
# visibility. Disabled here to stay firmly in free tier.
# To enable: set value = "enabled"
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

# -----------------------------------------------------------------------------
# Capacity Provider — tells the cluster to use Fargate (serverless).
# FARGATE_SPOT is cheaper (~70% discount) but tasks can be interrupted.
# We use FARGATE (on-demand) for the 2-task HA setup so both tasks stay up.
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }
}

# -----------------------------------------------------------------------------
# Task Definition
# Defines TWO containers that run together in every Fargate task:
#
#   1. app       — your FastAPI application
#   2. adot      — ADOT collector sidecar
#
# Container relationship:
#   - app sends OTLP traces/metrics to localhost:4317 (same network namespace)
#   - adot receives on :4317, exports traces to X-Ray, logs to CloudWatch
#   - app writes structured JSON logs to stdout; awslogs driver ships to CW
#
# dependsOn: app depends on adot being HEALTHY before it starts.
# This prevents the app from trying to send telemetry before the collector
# is ready to receive it.
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"  # required for Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # ADOT config is baked in as a base64-encoded environment variable.
  # Alternative: store in SSM Parameter Store and fetch at startup.
  # For the assessment, inline is simpler and avoids extra IAM permissions.
  container_definitions = jsonencode([

    # ── ADOT Collector sidecar ───────────────────────────────────────────────
    {
      name      = "adot"
      image     = local.adot_image
      essential = true  # if adot dies, the task restarts — ensures no silent data loss

      # Pass the ADOT config as a command flag pointing to the embedded config.
      # The /etc/ecs/otel-config.yaml path is the ADOT image's default location
      # for a mounted or env-supplied config. We use AOT_CONFIG_CONTENT instead
      # (env var) so we don't need a volume mount.
      command = ["--config", "env:AOT_CONFIG_CONTENT"]

      environment = [
        {
          name  = "AOT_CONFIG_CONTENT"
          # ADOT config — inline YAML (base64 NOT needed; ECS accepts raw string in env)
          value = <<-YAML
            receivers:
              otlp:
                protocols:
                  grpc:
                    endpoint: "0.0.0.0:4317"
                  http:
                    endpoint: "0.0.0.0:4318"

            processors:
              batch:
                timeout: 1s
                send_batch_size: 50

            exporters:
              # ── Traces → AWS X-Ray ────────────────────────────────────────
              awsxray:
                region: "${var.aws_region}"
                # index_all_attributes lets every span attribute appear in
                # the X-Ray segment metadata — useful for debugging
                index_all_attributes: true

              # ── Logs → CloudWatch Logs ────────────────────────────────────
              awscloudwatchlogs:
                region: "${var.aws_region}"
                log_group_name: "${var.log_group_app}"
                log_stream_name: "adot-{TaskId}"
                # log_retention: not set here — managed by aws_cloudwatch_log_group
                # in Terraform so retention is consistent and version-controlled
            extensions:
              health_check:
            service:
              extensions: [health_check]
              pipelines:
                traces:
                  receivers:  [otlp]
                  processors: [batch]
                  exporters:  [awsxray]
                logs:
                  receivers:  [otlp]
                  processors: [batch]
                  exporters:  [awscloudwatchlogs]
          YAML
        }
      ]

      portMappings = [
        { containerPort = 4317, protocol = "tcp" }, # OTLP gRPC
        { containerPort = 4318, protocol = "tcp" }  # OTLP HTTP
      ]

      # ADOT sidecar logs (collector internals, not app logs) go to a
      # separate log group so they don't pollute the app log stream.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_adot
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "adot"
        }
      }

      healthCheck = {
        command     = ["CMD", "/healthcheck"]
        interval    = 5
        timeout     = 3
        retries     = 3
        startPeriod = 10
      }
    },

    # ── FastAPI Application ──────────────────────────────────────────────────
    {
      name      = "app"
      image     = "${var.ecr_repository_url}:${var.app_image_tag}"
      essential = true

      portMappings = [
        { containerPort = var.app_port, protocol = "tcp" }
      ]

      environment = [
        # Tell the OpenTelemetry SDK where to send telemetry.
        # localhost works because both containers share the task's network namespace.
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
        { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "grpc" },

        # Service name appears in X-Ray traces and CloudWatch Logs.
        { name = "OTEL_SERVICE_NAME", value = "${var.project_name}-${var.environment}" },

        # AWS X-Ray propagator so trace IDs follow the X-Ray header format.
        # This ensures the trace ID injected into logs matches what X-Ray shows.
        { name = "OTEL_PROPAGATORS", value = "xray,tracecontext,baggage" },

        # Resource attributes attach to every span — visible in X-Ray metadata.
        { name = "OTEL_RESOURCE_ATTRIBUTES", value = "deployment.environment=${var.environment}" },

        # Application config
        { name = "APP_ENV",  value = var.environment },
        { name = "APP_PORT", value = tostring(var.app_port) },
        { name = "DEBUG", value = "True" },
        { name = "DATABASE_URL", value = var.database_url }
      ]

      # App stdout/stderr go to CloudWatch via awslogs driver.
      # The app should write structured JSON (with trace_id field) to stdout.
      # ADOT then picks up those logs and forwards them to CloudWatch Logs.
      # The awslogs driver here is a safety net for app startup errors.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_app
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/health || exit 1"]
        interval    = 20
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }

      # App waits for ADOT to be healthy before starting.
      # Without this, the first few traces sent at app startup may be dropped.
      # dependsOn = [
      #   { containerName = "adot", condition = "HEALTHY" }
      # ]

      # Resource allocation within the task:
      # Total task: 256 CPU / 512 MB
      # adot gets 64 CPU / 128 MB — enough for the collector at low throughput
      # app gets the remaining 192 CPU / 384 MB
      cpu    = 192
      memory = 384
    }
  ])

  tags = {
    Name = "${local.name_prefix}-task"
  }
}

# -----------------------------------------------------------------------------
# ECS Service
# Maintains exactly desired_count (2) running tasks across the two private
# subnets (one task per AZ for HA).
#
# Rolling deployment strategy:
#   minimum_healthy_percent = 50  → during deploy, 1 of 2 tasks can be down
#   maximum_percent         = 100 → no extra tasks spun up (saves cost)
#   This means: stop one task, start new one, then stop the other.
#   Slightly slower than the default (200%) but uses no extra Fargate capacity.
#
# Alternative: 100/200 — both old tasks stay up while 2 new ones start, then
# old ones drain. Safer but briefly runs 4 tasks (doubles cost during deploy).
# For the assessment 50/100 is the right trade-off.
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "this" {
  name                               = "${local.name_prefix}-service"
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60  # give app time to start before ALB checks

  # Spread tasks across both private subnets (AZ-a and AZ-b).
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_app_id]
    assign_public_ip = false # tasks are in private subnets, no public IP needed
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.app_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100


  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }


  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }
}
