# -----------------------------------------------------------------------------
# Remote state for the ECS layer.
# Use a different key from the VPC layer so the two states are independent —
# you can destroy/recreate ECS without touching the VPC.
# -----------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket       = "fastapi-fargate-tfstate"
    key          = "prod/ecs/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
