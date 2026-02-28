# Secure Three-Tier AWS Architecture

BLEN DevSecOps Engineer Take-Home: Secure Three-Tier Architecture

## Project Structure
```
/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   └── modules/
│       ├── networking/
│       ├── database/
│       ├── ecs/
│       └── alb/
├── app/
├── docker-compose.yml
├── .github/workflows/
│   ├── pr.yml
│   └── merge.yml
└── README.md
```

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

<img width="975" height="565" alt="image" src="https://github.com/user-attachments/assets/cd012686-c6cb-4f7f-be86-cffa933cf016" />


## Local Proof-of-Life

docker compose up builds the Next.js app and PostgreSQL database. Verified with:
<img width="975" height="673" alt="image" src="https://github.com/user-attachments/assets/f9e2c49b-5ee6-4776-9d4c-dcb01f92e79f" />


```
curl localhost:3000/api/db-check
```

### Docker Compose Up
<img width="975" height="252" alt="image" src="https://github.com/user-attachments/assets/e4f0afbf-5468-4a88-8cac-f2a62c9cb37d" />



### DB Check Response
<img width="849" height="88" alt="image" src="https://github.com/user-attachments/assets/ab239b10-4aaf-458d-b273-2f76f4e71744" />


## Running Locally
<img width="827" height="467" alt="image" src="https://github.com/user-attachments/assets/5289cd42-eb81-4da3-9c68-50da01fd895f" />

### Terraform Validation
```
terraform init -backend=false
<img width="906" height="594" alt="image" src="https://github.com/user-attachments/assets/7dd88328-5571-4c56-bfc9-0d4818d8d907" />

terraform fmt -check
<img width="916" height="67" alt="image" src="https://github.com/user-attachments/assets/0e181b92-a49f-4a86-9432-d7e994c668a8" />

terraform validate
<img width="949" height="109" alt="image" src="https://github.com/user-attachments/assets/589b7742-fe09-497b-bdae-3adb2853ec08" />

tflint 
<img width="589" height="38" alt="image" src="https://github.com/user-attachments/assets/38e5fe25-f9cf-4f2c-9c3c-31975f8b50ff" />

```


