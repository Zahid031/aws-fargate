# Terraform Project Structure

```
project/
├── vpc/                        ← Deploy FIRST
│   ├── backend.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars        ← copy from .example, fill in bucket name
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/                ← VPC, subnets, IGW, NAT, route tables
│       ├── security_group/     ← reusable SG module
│       └── vpc_endpoints/      ← ECR, S3, CloudWatch, X-Ray endpoints
│
└── ecs/                        ← Deploy SECOND (reads vpc remote state)
    ├── backend.tf
    ├── provider.tf
    ├── variables.tf
    ├── main.tf
    ├── outputs.tf
    ├── terraform.tfvars        ← copy from .example, fill in bucket name
    ├── terraform.tfvars.example
    └── modules/
        ├── ecr/                ← ECR repository + lifecycle policy
        ├── iam/                ← execution role + task role
        ├── alb/                ← ALB, target group, HTTP listener
        └── ecs/                ← cluster, task definition, service
```

## Deploy Order

### Prerequisites
```bash
# Create the S3 state bucket ONCE (replace with your unique name)
aws s3api create-bucket \
  --bucket tfstate-fastapi-fargate-<YOUR-ACCOUNT-ID> \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket tfstate-fastapi-fargate-<YOUR-ACCOUNT-ID> \
  --versioning-configuration Status=Enabled
```

### Step 1 — VPC
```bash
cd vpc/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — update bucket name
# Edit backend.tf        — update bucket name

terraform init
terraform plan
terraform apply
```

### Step 2 — ECS
```bash
cd ../ecs/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — update vpc_state_bucket to your bucket name
# Edit backend.tf        — update bucket name

terraform init
terraform plan
terraform apply

# Get the ALB URL
terraform output alb_dns_name
```

### Tear Down (in reverse order)
```bash
cd ecs/   && terraform destroy
cd ../vpc/ && terraform destroy
```
