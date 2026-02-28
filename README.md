# Secure Three-Tier AWS Architecture

BLEN DevSecOps Engineer Take-Home: Secure Three-Tier Architecture

## Project Structure

/
├── terraform/              # Modular Terraform configuration
│   ├── main.tf             # Root module wiring
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   └── modules/
│       ├── networking/     # VPC, subnets, IGW, NAT GW, route tables
│       ├── database/       # RDS PostgreSQL, Secrets Manager
│       ├── ecs/            # ECS Fargate, IAM roles, task definition
│       └── alb/            # ALB, target group, listeners
├── app/                    # Next.js application (provided)
├── docker-compose.yml      # Local proof-of-life
├── .github/workflows/
│   ├── pr.yml              # PR checks pipeline
│   └── merge.yml           # Merge + GHCR publish pipeline
└── README.md

## Architecture Decisions

- **Modular Terraform**: Split into networking, database, ecs, and alb modules for reusability and separation of concerns.
- **Security group wiring**: Created empty security groups in the root module and passed IDs into each module. Rules are attached via aws_security_group_rule resources. This avoids circular dependencies between ALB, ECS, and RDS.
- **Three subnet tiers**: Public (ALB, NAT GW), private (ECS Fargate), and isolated (RDS). Isolated subnets have no route to the internet.
- **Dual NAT Gateways**: One per AZ for high availability. If one AZ goes down, the other still has outbound internet access.
- **Multi-AZ RDS**: Primary and standby in separate AZs for failover.
- **Secrets Manager**: DB credentials stored in Secrets Manager and injected into ECS tasks at runtime. No hardcoded secrets.

## Security Considerations

- RDS is in isolated subnets with no internet access and publicly_accessible = false
- RDS storage encryption enabled
- IAM database authentication enabled
- Security groups follow least-privilege: each tier only accepts traffic from the tier above it on the required port
- ECS tasks run in private subnets, outbound only via NAT GW
- ALB drops invalid header fields
- HTTP listener redirects to HTTPS (no plaintext traffic served)
- VPC flow logging enabled
- Default VPC security group restricts all traffic
- DB credentials in Secrets Manager, never hardcoded
- All CI pipelines include checkov, hadolint, Trivy, and gitleaks

## Checkov Skips (with justification)

| Check | Resource | Reason |
|-------|----------|--------|
| CKV_AWS_260 | ALB HTTP ingress | HTTP listener used solely for HTTPS redirect |
| CKV_AWS_91 | ALB | Access logs require S3 bucket, out of scope |
| CKV_AWS_150 | ALB | Deletion protection disabled for assessment |
| CKV_AWS_149 | Secrets Manager | Default AWS encryption sufficient, KMS CMK out of scope |
| CKV_AWS_293 | RDS | Deletion protection disabled for assessment |
| CKV_AWS_158 | CloudWatch Logs | KMS encryption for log groups out of scope |
| CKV2_AWS_28 | ALB | WAF out of scope |
| CKV2_AWS_30 | RDS | Query logging via parameter group out of scope |
| CKV2_AWS_57 | Secrets Manager | Secret rotation requires Lambda, out of scope |

## Local Proof-of-Life

docker compose up builds the Next.js app and PostgreSQL database. Verified with:
```
curl localhost:3000/api/db-check
```

### Docker Compose Up


### DB Check Response


## Running Locally

### Terraform Validation
```
cd terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
tflint --recursive
checkov -d .
```

### Docker Compose
```
docker compose up --build -d
curl localhost:3000/api/db-check
docker compose down
```
