# FastAPI on AWS Fargate

> **Live URL:** [http://fastapi-fargate-prod-alb-927297647.us-east-1.elb.amazonaws.com/health](http://fastapi-fargate-prod-alb-927297647.us-east-1.elb.amazonaws.com/health)
> **Repository:** [github.com/Zahid031/aws-fargate](https://github.com/Zahid031/aws-fargate)

A production-ready deployment of a **FastAPI** application on **AWS ECS Fargate**, fully provisioned with **Terraform** and automated through a **GitHub Actions CI/CD pipeline**. This project demonstrates cloud-native engineering best practices — infrastructure-as-code, containerization, observability, secure network architecture, and zero-downtime deployments.

---

## Architecture

![Fargate Architecture](fargate-architecture.drawio.png)

The diagram above illustrates the full system. Here's how it all fits together:

```
                        ┌─────────────────────────────────────────────┐
                        │               AWS Cloud (us-east-1)          │
                        │                                               │
   Users / Internet ───▶│  [Application Load Balancer]                 │
                        │     Public Subnets (AZ-a, AZ-b)              │
                        │           │ port 8000 (ALB SG only)          │
                        │           ▼                                   │
                        │  [ECS Fargate Service]                        │
                        │     Private Subnets (AZ-a, AZ-b)             │
                        │     ┌─────────────────────────┐              │
                        │     │   Fargate Task           │              │
                        │     │  ┌────────┐ ┌────────┐  │              │
                        │     │  │  app   │◀│  adot  │  │              │
                        │     │  │FastAPI │ │sidecar │  │              │
                        │     │  └────────┘ └────────┘  │              │
                        │     └─────────────────────────┘              │
                        │           │                                   │
                        │    ┌──────┼──────────────┐                   │
                        │    ▼      ▼               ▼                  │
                        │  [ECR] [X-Ray]   [CloudWatch Logs]           │
                        │    ▲                                          │
                        │  [S3 VPC Endpoint] ◀── image layer pulls     │
                        │                                               │
                        │  [EC2 Bastion] ──▶ [EC2 PostgreSQL]          │
                        │     Private Subnets                           │
                        └─────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **Private subnets for Fargate tasks** | No public IPs on containers — all inbound traffic flows through the ALB |
| **`sg_app` scoped to `sg_alb` (not VPC CIDR)** | Only the ALB can reach the app on port 8000; allowing the full VPC CIDR is a common security mistake |
| **Two separate IAM roles** | `execution_role` for the ECS control plane (image pull, startup logs); `task_role` for the running container (X-Ray, CloudWatch). Merging them is a security anti-pattern |
| **VPC Endpoints (ECR, S3, CloudWatch, X-Ray)** | Keeps AWS service traffic on the AWS backbone — avoids NAT Gateway data-transfer costs and reduces latency |
| **Two tasks across two AZs** | High availability — one task per Availability Zone; an AZ outage doesn't take the service down |
| **Rolling deploy: 50% min / 100% max** | Stop one task → start new one → stop the other. No extra Fargate capacity needed during deployment |
| **ADOT sidecar pattern** | Decouples telemetry from the app. App sends OTLP to `localhost:4317`; ADOT routes to X-Ray and CloudWatch |
| **Layered Terraform (VPC → ECS)** | VPC and ECS are separate root modules linked by S3 remote state — clean separation, independently deployable |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Python 3.13, FastAPI, SQLAlchemy (async), Pydantic v2 |
| Database | PostgreSQL via psycopg3 (async) |
| Container | Docker, AWS ECR |
| Orchestration | AWS ECS Fargate |
| Networking | AWS VPC, ALB, NAT Gateway, VPC Endpoints, Security Groups |
| Infrastructure | Terraform (modular, S3 remote state) |
| Observability | OpenTelemetry SDK, AWS ADOT Collector sidecar, AWS X-Ray, CloudWatch Logs |
| CI/CD | GitHub Actions |
| Package Manager | `uv` (Astral — fast Python package manager) |
| Code Quality | Ruff (lint + format), pre-commit hooks, `ty` (type checker) |

---

## Application

The FastAPI app follows a clean **layered architecture** with strict separation between transport, business logic, and data access layers.

```
src/
├── main.py                  # App entry point — router registration, lifespan (DB init)
└── core/
│   ├── config.py            # Pydantic BaseSettings — reads DATABASE_URL, DEBUG from .env
│   ├── db.py                # Async SQLAlchemy engine + session factory
│   ├── dependencies.py      # FastAPI DI wiring: session → repo → service
│   └── init_db.py           # Creates all ORM tables on startup
└── modules/
    └── hero/
        ├── api.py           # Route handlers (FastAPI APIRouter)
        ├── models.py        # SQLAlchemy ORM model (Hero table)
        ├── schemas.py       # Pydantic I/O schemas (HeroCreate, HeroRead)
        ├── service.py       # Business logic — raises HTTP 404 if hero not found
        └── repository.py   # All DB queries (create, list, get by id, delete)
```

### API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — used by the ALB target group |
| `POST` | `/heroes/` | Create a new hero |
| `GET` | `/heroes/?offset=0&limit=100` | List heroes (paginated) |
| `GET` | `/heroes/{id}` | Get a single hero by ID |
| `DELETE` | `/heroes/{id}` | Delete a hero by ID |

**Try it live:**
```
GET http://fastapi-fargate-prod-alb-927297647.us-east-1.elb.amazonaws.com/health
GET http://fastapi-fargate-prod-alb-927297647.us-east-1.elb.amazonaws.com/heroes/
```

Interactive Swagger docs available at `/docs` on the live URL.

### Environment Variables

```env
DATABASE_URL=postgresql+psycopg://user:password@host:5432/dbname
DEBUG=True
```

---

## Infrastructure

The Terraform code is split into two independent, layered root modules. They are deployed in order and share state via an **S3 remote state backend**.

### Layer 1 — VPC (`terraform-modules/vpc/`)

Provisions all networking:

- Custom VPC with configurable CIDR
- Public and private subnets across **two Availability Zones**
- Internet Gateway for public subnets
- NAT Gateway for private subnet outbound traffic
- Route tables with correct public/private associations
- **Security Groups** (reusable module):
  - `sg_alb` — accepts HTTP (80) and HTTPS (443) from `0.0.0.0/0`
  - `sg_app` — accepts port 8000 **only from `sg_alb`** (not broad VPC CIDR)
  - `sg_endpoint` — accepts HTTPS 443 from `sg_app` for VPC endpoint traffic
- **VPC Endpoints** (toggled via `enable_vpc_endpoints` variable):
  - **S3 Gateway** (free) — covers ECR image layer pulls from S3
  - **ECR API + ECR DKR** (interface) — ECR auth and image manifest fetch
  - **CloudWatch Logs** (interface) — ADOT sidecar log export
  - **X-Ray** (interface) — ADOT trace export

### Layer 2 — ECS (`terraform-modules/ecs/`)

Reads VPC outputs via remote state and provisions:

- **ECR Repository** — stores Docker images; scan-on-push enabled
- **IAM Roles**:
  - `execution_role` — used by ECS control plane to pull images and write startup logs
  - `task_role` — used by running containers to write X-Ray traces and CloudWatch logs
- **CloudWatch Log Groups** — separate groups for `app` and `adot` sidecar logs
- **Application Load Balancer** — HTTP listener on port 80, target group with `/health` health check
- **ECS Cluster** — Fargate capacity provider (on-demand for HA stability)
- **ECS Task Definition** — two containers per task:
  - **`app`** — FastAPI, auto-instrumented by OpenTelemetry at the Docker entrypoint
  - **`adot`** — AWS ADOT Collector sidecar, receives OTLP on `localhost:4317/4318`, exports traces to X-Ray and logs to CloudWatch
- **ECS Service** — `desired_count = 2`, rolling deploy 50/100, circuit breaker with automatic rollback on failure
- **EC2 module** — Bastion host + PostgreSQL instance in private subnets

### Terraform Module Tree

```
terraform-modules/
├── vpc/                          ← Deploy FIRST
│   ├── main.tf                   # Composes all VPC modules
│   ├── variables.tf / outputs.tf
│   └── modules/
│       ├── vpc/                  # VPC, subnets, IGW, NAT, route tables
│       ├── security_group/       # Reusable SG module (ingress rules as input)
│       └── vpc_endpoints/        # ECR, S3, CloudWatch, X-Ray endpoints
│
└── ecs/                          ← Deploy SECOND (reads vpc remote state)
    ├── main.tf                   # Composes all ECS modules
    ├── variables.tf / outputs.tf
    └── modules/
        ├── ecr/                  # Container registry + lifecycle policy
        ├── iam/                  # execution_role + task_role
        ├── alb/                  # ALB, target group, listener
        ├── ecs/                  # Cluster, task definition (app + adot), service
        └── ec2/                  # Bastion + Postgres EC2 instances
```

---

## Observability

The app ships with **end-to-end distributed tracing and structured logging** using the OpenTelemetry standard.

**How the telemetry pipeline works:**

```
FastAPI app
  │  (auto-instrumented via `opentelemetry-instrument` at Docker ENTRYPOINT)
  │
  ▼ OTLP gRPC → localhost:4317
ADOT Collector sidecar
  ├──▶ AWS X-Ray         (distributed traces)
  └──▶ CloudWatch Logs   (structured logs)
```

Both containers share the same **network namespace** inside the Fargate task, so `localhost:4317` works with zero extra networking config.

**Instrumented libraries:**
- `opentelemetry-instrumentation-fastapi` — HTTP request spans
- `opentelemetry-instrumentation-sqlalchemy` — database query spans
- `opentelemetry-instrumentation-httpx` — outbound HTTP spans
- `opentelemetry-instrumentation-psycopg2` — PostgreSQL driver spans

**OTEL environment variables set in the ECS task definition:**

```
OTEL_EXPORTER_OTLP_ENDPOINT  = http://localhost:4317
OTEL_EXPORTER_OTLP_PROTOCOL  = grpc
OTEL_SERVICE_NAME             = fastapi-fargate-prod
OTEL_PROPAGATORS              = xray,tracecontext,baggage
OTEL_RESOURCE_ATTRIBUTES      = deployment.environment=prod
```

The `xray` propagator ensures trace IDs follow the AWS X-Ray format — trace IDs in CloudWatch logs match exactly what appears in the X-Ray console, enabling seamless log-to-trace correlation.

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) triggers on every push to `main` and runs two sequential jobs.

### Pipeline Flow

```
git push → main
     │
     ▼
┌─────────────────────────┐
│   Job 1: build-and-push │
│                         │
│  1. Checkout code       │
│  2. Configure AWS creds │
│  3. Login to ECR        │
│  4. Build Docker image  │
│     tag: <short-git-sha>│
│  5. Push to ECR         │
│  6. Output image URI    │
└──────────┬──────────────┘
           │ image-uri output
           ▼
┌─────────────────────────┐
│   Job 2: deploy         │
│                         │
│  1. Configure AWS creds │
│  2. Fetch live task def │
│     (no config drift)   │
│  3. Render new task def │
│     (updated image)     │
│  4. Deploy to ECS       │
│  5. Wait for stability  │
└─────────────────────────┘
```

**Notable choices:**
- Images are tagged with the **short Git SHA** (8 chars) — every running container is traceable back to a commit
- The live task definition is **fetched from AWS at deploy time** — never stored in the repo to avoid drift
- `wait-for-service-stability: true` — the pipeline only goes green when ECS confirms new tasks are healthy
- Deployment circuit breaker will **automatically roll back** if the new tasks fail health checks

---

## Local Development

**Prerequisites:** Python 3.13+, `uv`, a running PostgreSQL instance

```bash
# 1. Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Clone the repo
git clone https://github.com/Zahid031/aws-fargate.git
cd aws-fargate

# 3. Create virtualenv and install dependencies
uv venv --python 3.13
source .venv/bin/activate
uv sync

# 4. Configure environment
cp .env.example .env
# Edit .env — set DATABASE_URL to your local PostgreSQL connection string

export PYTHONPATH=$(pwd)
export $(xargs < .env)

# 5. Run the development server
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

App at `http://localhost:8000` — Swagger UI at `http://localhost:8000/docs`.

### Run with Docker

```bash
docker build -t fastapi-fargate .
docker run -p 8000:8000 --env-file .env fastapi-fargate
```

---

## Deployment Guide

### Prerequisites

```bash
# One-time: create S3 bucket for Terraform remote state
aws s3api create-bucket \
  --bucket tfstate-fastapi-fargate-<YOUR-ACCOUNT-ID> \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket tfstate-fastapi-fargate-<YOUR-ACCOUNT-ID> \
  --versioning-configuration Status=Enabled
```

### Step 1 — Deploy VPC

```bash
cd terraform-modules/vpc/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars → update S3 bucket name
# Edit backend.tf        → update S3 bucket name

terraform init
terraform plan
terraform apply
```

### Step 2 — Deploy ECS

```bash
cd ../ecs/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars → set vpc_state_bucket to your S3 bucket
# Edit backend.tf        → update S3 bucket name

terraform init
terraform plan
terraform apply

# Get the live ALB URL
terraform output alb_dns_name
```

### Step 3 — Configure CI/CD

Add these secrets to your GitHub repository (`Settings → Secrets and variables → Actions`):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Push to `main` — the pipeline will build, push, and deploy automatically.

### Tear Down

```bash
cd terraform-modules/ecs/ && terraform destroy
cd ../vpc/                 && terraform destroy
```

---

## Project Structure

```
aws-fargate/
├── .github/
│   └── workflows/
│       └── ci.yml                    # GitHub Actions CI/CD pipeline
├── src/
│   ├── main.py                       # FastAPI app, lifespan, router registration
│   ├── core/
│   │   ├── config.py                 # Pydantic settings (DATABASE_URL, DEBUG)
│   │   ├── db.py                     # Async SQLAlchemy engine + session
│   │   ├── dependencies.py           # FastAPI DI: session → repo → service
│   │   └── init_db.py               # Auto-creates tables on startup
│   └── modules/
│       └── hero/
│           ├── api.py                # Route handlers
│           ├── models.py             # SQLAlchemy ORM model
│           ├── schemas.py            # Pydantic request/response schemas
│           ├── service.py            # Business logic (404 handling)
│           └── repository.py        # All database queries
├── terraform-modules/
│   ├── vpc/                          # Layer 1: VPC, subnets, SGs, VPC endpoints
│   │   └── modules/
│   │       ├── vpc/
│   │       ├── security_group/
│   │       └── vpc_endpoints/
│   └── ecs/                          # Layer 2: ECR, IAM, ALB, ECS Fargate, EC2
│       └── modules/
│           ├── ecr/
│           ├── iam/
│           ├── alb/
│           ├── ecs/
│           └── ec2/
├── fargate-architecture.drawio.png   # Architecture diagram
├── Dockerfile                        # uv-based build + ADOT bootstrap at entrypoint
├── pyproject.toml                    # Dependencies + project metadata
└── .env.example                      # Environment variable template
```