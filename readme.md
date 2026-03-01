# Multi-Region AI Video Analytics – Terraform IaC

Production-ready Terraform infrastructure for a multi-region serverless API on AWS with centralized Cognito authentication.

## Architecture

```
                        ┌─────────────────────────┐
                        │   Amazon Cognito         │
                        │   User Pool (us-east-1)  │
                        └────────┬────────────────┘
                                 │ JWT Tokens
                 ┌───────────────┴────────────────┐
                 ▼                                 ▼
      ┌─────────────────────┐           ┌─────────────────────┐
      │    us-east-1         │           │    eu-west-1         │
      │                     │           │                     │
      │  API Gateway (HTTP) │           │  API Gateway (HTTP) │
      │  ├─ POST /greet     │           │  ├─ POST /greet     │
      │  └─ POST /dispatch  │           │  └─ POST /dispatch  │
      │                     │           │                     │
      │  Lambda (Greeter)   │           │  Lambda (Greeter)   │
      │  ├─ DynamoDB Write  │           │  ├─ DynamoDB Write  │
      │  └─ SNS Publish     │           │  └─ SNS Publish     │
      │                     │           │                     │
      │  Lambda (Dispatcher)│           │  Lambda (Dispatcher)│
      │  └─ ECS RunTask     │           │  └─ ECS RunTask     │
      │                     │           │                     │
      │  ECS Fargate        │           │  ECS Fargate        │
      │  (aws-cli → SNS)    │           │  (aws-cli → SNS)    │
      │                     │           │                     │
      │  DynamoDB Table     │           │  DynamoDB Table     │
      │  (GreetingLogs)     │           │  (GreetingLogs)     │
      │                     │           │                     │
      │  VPC (public-only)  │           │  VPC (public-only)  │
      └─────────────────────┘           └─────────────────────┘
```

## Prerequisites

| Tool      | Version  | Purpose                              |
|-----------|----------|--------------------------------------|
| Terraform | ≥ 1.5.0  | Infrastructure provisioning          |
| AWS CLI   | v2       | Credential management & testing      |
| Python    | ≥ 3.10   | Integration test script              |
| pip       | latest   | Install `boto3` and `requests`       |

## Quick Start

### 1. Clone & Configure AWS Credentials

```powershell
git clone https://github.com/yourusername/aws-assessment.git
cd aws-assessment

# Configure a named AWS CLI profile
aws configure --profile myprofile
$env:AWS_PROFILE = "myprofile"
```

### 2. Set Variables

```powershell
# Copy the example and fill in your values
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_profile = "myprofile"
email       = "your_email@example.com"
github_repo = "https://github.com/yourusername/aws-assessment"
sns_topic_arn = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
```

### 3. Deploy

```powershell
terraform init
terraform fmt -check          # lint
terraform validate            # syntax check
terraform plan -out=tfplan    # preview changes
terraform apply tfplan        # deploy
```

### 4. Set Cognito Test User Password

After the first deploy, set a permanent password for the test user:

```powershell
aws cognito-idp admin-set-user-password `
  --user-pool-id $(terraform output -raw cognito_user_pool_id) `
  --username testuser `
  --password "YourSecureP@ss1" `
  --permanent `
  --region us-east-1
```

### 5. Run Integration Tests

```powershell
pip install boto3 requests

$env:COGNITO_CLIENT_ID     = "$(terraform output -raw cognito_user_pool_client_id)"
$env:COGNITO_USERNAME      = "testuser"
$env:COGNITO_PASSWORD      = "YourSecureP@ss1"
$env:API_ENDPOINT_US_EAST  = "$(terraform output -raw api_endpoint_us_east)"
$env:API_ENDPOINT_EU_WEST  = "$(terraform output -raw api_endpoint_eu_west)"

python test_endpoints.py
```

### 6. Manual Endpoint Test

```powershell
# Get an ID token
$token = aws cognito-idp initiate-auth `
  --client-id $(terraform output -raw cognito_user_pool_client_id) `
  --auth-flow USER_PASSWORD_AUTH `
  --auth-parameters USERNAME=testuser,PASSWORD="YourSecureP@ss1" `
  --query "AuthenticationResult.IdToken" `
  --output text `
  --region us-east-1

# Call /greet
$api = "$(terraform output -raw api_endpoint_us_east)"
Invoke-RestMethod -Method Post -Uri "$api/greet" `
  -Body '{"message":"hello"}' `
  -ContentType 'application/json' `
  -Headers @{ Authorization = $token }
```

## Project Structure

```
.
├── main.tf                         # Cognito + module instances + outputs
├── variables.tf                    # Root input variables
├── providers.tf                    # Provider config (us-east-1, eu-west-1)
├── terraform.tfvars.example        # Example variable values
├── test_endpoints.py               # Integration test script
│
├── modules/app_stack/              # Reusable per-region module
│   ├── variables.tf                # Module inputs
│   ├── outputs.tf                  # Module outputs
│   ├── dynamodb.tf                 # DynamoDB table
│   ├── iam.tf                      # IAM roles & policies
│   ├── lambda.tf                   # Lambda functions + archives
│   ├── api_gateway.tf              # HTTP API + Cognito JWT authorizer
│   ├── vpc.tf                      # Public-only VPC (no NAT)
│   ├── ecs.tf                      # ECS cluster + Fargate task
│   └── lambda/
│       ├── greet.py                # Greeter handler
│       └── dispatch.py             # Dispatcher handler
│
└── .github/workflows/
    └── terraform.yml               # CI/CD pipeline
```

## Variables Reference

| Variable             | Required | Default                              | Description                            |
|----------------------|----------|--------------------------------------|----------------------------------------|
| `aws_profile`        | No       | `""`                                 | AWS CLI profile name                   |
| `aws_region_us_east` | No       | `us-east-1`                          | Primary region                         |
| `aws_region_eu_west` | No       | `eu-west-1`                          | Secondary region                       |
| `environment`        | No       | `dev`                                | Environment label                      |
| `email`              | **Yes**  | `pythoncourse358@gmail.com`          | Email for Cognito user & SNS payload   |
| `github_repo`        | **Yes**  | `https://github.com/user/aws-assessment` | Repo URL for SNS payload         |
| `sns_topic_arn`      | **Yes**  | Candidate Verification Topic         | SNS topic for verification messages    |

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/terraform.yml`) runs on pushes and PRs to `main`:

| Stage        | Trigger    | What it does                                            |
|--------------|------------|---------------------------------------------------------|
| **Lint**     | Always     | `terraform fmt -check -recursive`                       |
| **Validate** | Always     | `terraform init && terraform validate`                  |
| **Plan**     | PR only    | `terraform plan` — posts output as PR comment           |
| **Apply**    | Main only  | `terraform apply -auto-approve` (manual approval gate)  |
| **Test**     | After apply| Runs `test_endpoints.py` against live endpoints         |

### Required GitHub Secrets

| Secret                  | Description                                |
|-------------------------|--------------------------------------------|
| `AWS_ROLE_ARN`          | IAM role ARN for GitHub OIDC authentication|
| `COGNITO_USERNAME`      | Test user username                         |
| `COGNITO_PASSWORD`      | Test user password                         |
| `TF_VAR_email`          | Email for SNS payload                      |
| `TF_VAR_github_repo`    | GitHub repo URL for SNS payload            |
| `TF_VAR_sns_topic_arn`  | SNS topic ARN                              |

## Security Notes

- **Never commit credentials.** Use `AWS_PROFILE` or environment variables.
- `terraform.tfvars` is gitignored — only `.example` is tracked.
- Terraform state contains sensitive data. For production, use [S3 remote backend](https://developer.hashicorp.com/terraform/language/backend/s3) with encryption and DynamoDB state locking.
- API Gateway routes are protected by Cognito JWT authorizer — unauthenticated requests receive `401 Unauthorized`.

## Cost Optimisation

- **No NAT Gateways** — Fargate tasks use public subnets with public IPs.
- **DynamoDB PAY_PER_REQUEST** — zero cost at rest.
- **Lambda** — billed per invocation only.
- **Fargate** — tasks run on-demand; no idle cost.

## Cleanup

```powershell
terraform destroy -auto-approve
```

This will tear down **all** resources in both regions.
