# Multi-Region AI Video Analytics Infrastructure

## 🏗️ Architecture
- **Global Auth:** Amazon Cognito (Primary: us-east-1).
- **Compute:** Dual-region deployment (us-east-1, eu-west-1) featuring Lambda and ECS Fargate.
- **Data:** Regional DynamoDB tables for localized greeting logs.
- **Verification:** Cross-region SNS publishing to a centralized "Unleash" topic.

## 📁 Project Structure
├── .github/workflows/    # CI/CD Pipeline (GitHub Actions)
├── modules/              # Reusable regional modules
│   ├── compute/          # Lambda, ECS, API Gateway
│   └── database/         # DynamoDB
├── scripts/              # Automated Test Scripts (Python/Node)
├── main.tf               # Root module calling regional modules
├── providers.tf          # Multi-region provider aliases
└── variables.tf          # Global vars (email, repo_url)

## 🚀 Deployment Steps
1. **Initialize:** `terraform init`
2. **Plan:** `terraform plan -out=tfplan`
3. **Apply:** `terraform apply tfplan`
4. **Test:** `python scripts/test_deployment.py`

## 🧪 Testing Protocol
The test script performs:
1. `AdminInitiateAuth` to fetch a JWT for `your_email@example.com`.
2. Parallel `GET` requests to regional `/greet` endpoints.
3. Parallel `POST` requests to regional `/dispatch` endpoints.
4. Latency comparison and region-header validation.