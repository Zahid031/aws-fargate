
terraform {
  backend "s3" {
    bucket       = "fastapi-fargate-tfstate" 
    key          = "prod/vpc/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true 
  }
}
