# Multi-Region Serverless API – Terraform IaC

Terraform infrastructure for a **multi-region serverless API** on AWS with centralized Cognito authentication, Lambda-backed endpoints, DynamoDB persistence, and an ECS Fargate dispatcher — deployed across `us-east-1` and `eu-west-1`.

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

### IAM Permissions

The AWS IAM user needs `AdministratorAccess` or permissions for: **Cognito**, **Lambda**, **API Gateway v2**, **DynamoDB**, **ECS/Fargate**, **IAM**, **VPC/EC2**, **CloudWatch Logs**, **SNS**, and **S3**.

---

## Deployment

You can deploy **locally from the CLI** or **automatically via GitHub Actions CI/CD**. Both methods share the same remote state in S3.

### One-Time Setup (required for both methods)

**1. Create the remote state backend** (S3 bucket + DynamoDB lock table):

```powershell
aws s3api create-bucket --bucket YOUR_BUCKET_NAME --region us-east-1
aws s3api put-bucket-versioning --bucket YOUR_BUCKET_NAME --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name YOUR_LOCK_TABLE `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST --region us-east-1
```

---

### Option A – Deploy Locally (CLI)

**What you need:** AWS CLI credentials configured, `terraform.tfvars` file.

**1. Configure AWS credentials:**

```powershell
aws configure --profile myprofile
$env:AWS_PROFILE = "myprofile"
```

**2. Create `terraform.tfvars`:**

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_profile   = "myprofile"
email         = "your_email@example.com"
github_repo   = "https://github.com/your-org/your-repo"
sns_topic_arn = "arn:aws:sns:us-east-1:ACCOUNT_ID:TOPIC_NAME"
```

**3. Init, plan, and apply:**

```powershell
terraform init `
  -backend-config="bucket=YOUR_BUCKET_NAME" `
  -backend-config="key=terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=YOUR_LOCK_TABLE" `
  -backend-config="encrypt=true"

terraform plan -out=tfplan
terraform apply tfplan
```

**4. Set Cognito test user password (first deploy only):**

```powershell
aws cognito-idp admin-set-user-password `
  --user-pool-id $(terraform output -raw cognito_user_pool_id) `
  --username testuser `
  --password "YourSecureP@ss1" `
  --permanent `
  --region us-east-1
```

**5. Destroy (when done):**

```powershell
terraform destroy -auto-approve
```

---

### Option B – Deploy via GitHub Actions CI/CD

**What you need:** GitHub Secrets configured in your repo settings.

The pipeline runs **automatically** on push/PR to `main`. You can also **manually trigger** apply or destroy from the Actions tab.

**1. Add these secrets** in **Settings → Secrets and variables → Actions**:

| Secret                    | Value                                       |
|---------------------------|---------------------------------------------|
| `AWS_ACCESS_KEY_ID`       | IAM access key                              |
| `AWS_SECRET_ACCESS_KEY`   | IAM secret key                              |
| `TF_BACKEND_BUCKET`       | Your S3 state bucket name                   |
| `TF_BACKEND_LOCK_TABLE`   | Your DynamoDB lock table name               |
| `TF_VAR_email`            | Your email address                          |
| `TF_VAR_github_repo`      | Your GitHub repo URL                        |
| `TF_VAR_sns_topic_arn`    | SNS topic ARN                               |
| `COGNITO_USERNAME`        | `testuser`                                  |
| `COGNITO_PASSWORD`        | Password for the test user                  |

**2. Pipeline stages:**

| Stage        | Trigger            | What it does                                        |
|--------------|--------------------|-----------------------------------------------------|
| **Lint**     | Every push/PR      | `terraform fmt -check -recursive`                   |
| **Validate** | Every push/PR      | `terraform init && terraform validate`              |
| **Plan**     | PR only            | `terraform plan` — posts output as PR comment       |
| **Apply**    | Push to main       | `terraform apply -auto-approve`                     |
| **Test**     | After apply        | Runs `test_endpoints.py` against live endpoints     |
| **Destroy**  | Manual only        | `terraform destroy -auto-approve`                   |

**3. Manual trigger:** Go to **Actions → Terraform CI/CD → Run workflow** and select `apply` or `destroy`.

---

## Testing

### Automated Integration Tests

```powershell
pip install boto3 requests

$env:COGNITO_CLIENT_ID     = "$(terraform output -raw cognito_user_pool_client_id)"
$env:COGNITO_USERNAME      = "testuser"
$env:COGNITO_PASSWORD      = "YourSecureP@ss1"
$env:API_ENDPOINT_US_EAST  = "$(terraform output -raw api_endpoint_us_east)"
$env:API_ENDPOINT_EU_WEST  = "$(terraform output -raw api_endpoint_eu_west)"

python test_endpoints.py
```

### Manual Endpoint Test

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

---

## Project Structure

```
.
├── main.tf                         # Cognito + module instances + outputs
├── variables.tf                    # Root input variables
├── providers.tf                    # Provider & S3 backend config
├── terraform.tfvars.example        # Example variable values
├── test_endpoints.py               # Integration test script
│
├── modules/app_stack/              # Reusable per-region module
│   ├── variables.tf                # Module inputs
│   ├── outputs.tf                  # Module outputs
│   ├── providers.tf                # Provider requirements
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

| Variable             | Required | Default        | Description                            |
|----------------------|----------|----------------|----------------------------------------|
| `aws_profile`        | No       | `""`           | AWS CLI profile name                   |
| `aws_region_us_east` | No       | `us-east-1`    | Primary region                         |
| `aws_region_eu_west` | No       | `eu-west-1`    | Secondary region                       |
| `environment`        | No       | `dev`          | Environment label                      |
| `email`              | **Yes**  | —              | Email for Cognito user & SNS payload   |
| `github_repo`        | **Yes**  | —              | GitHub repo URL for SNS payload        |
| `sns_topic_arn`      | **Yes**  | —              | SNS topic ARN for verification messages|

## Security Notes

- **Never commit credentials.** Use `AWS_PROFILE` or environment variables.
- `terraform.tfvars` is gitignored — only `.example` is tracked.
- Terraform state is stored in an encrypted S3 bucket with DynamoDB state locking.
- API Gateway routes are protected by Cognito JWT authorizer — unauthenticated requests receive `401 Unauthorized`.

## Cost Optimisation

- **No NAT Gateways** — Fargate tasks use public subnets with public IPs.
- **DynamoDB PAY_PER_REQUEST** — zero cost at rest.
- **Lambda** — billed per invocation only.
- **Fargate** — tasks run on-demand; no idle cost.
