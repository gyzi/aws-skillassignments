# Multi-Region AI Video Analytics (minimal module + guide)

This folder contains a small Terraform root plus a reusable module `modules/app_stack` that provisions the application stack for a single region:

- A DynamoDB table `GreetingLogs`.
- An HTTP API (API Gateway v2) exposing POST /greet and POST /dispatch.
- A Lambda function that backs `/greet`, writes a record into DynamoDB and publishes a JSON payload to an SNS topic.

This README documents how to use the module, how to provide AWS credentials safely, and quick deploy steps.

## Module: modules/app_stack

Inputs
- `cognito_user_pool_arn` (string) — ARN of an existing Cognito user pool (kept for reference/permissions).
- `region_name` (string) — region where the module will create resources.
- `sns_topic_arn` (string) — ARN of the SNS topic to which `/greet` will publish a JSON message.

Outputs
- `dynamodb_table_name` — the DynamoDB table name (`GreetingLogs`).
- `api_endpoint` — the HTTP API endpoint (invoke to hit `/greet` and `/dispatch`).
- `greet_lambda_arn` — the Lambda function ARN for the `/greet` handler.

Important notes
- The module creates an IAM role with permissions to PutItem on the DynamoDB table and Publish to the SNS ARN you supply. Ensure the SNS ARN is correct and the principal has permission to publish.
- The Lambda uses Python 3.11 and relies on the built-in `boto3` library — no external packaging is required.

## How to deploy (PowerShell)

1) Provide AWS credentials securely (preferred: profile or env vars)

```powershell
# Using named profile (recommended)
aws configure --profile myprofile
$env:AWS_PROFILE = 'myprofile'

# Or set the environment variables for the current shell only:
$env:AWS_ACCESS_KEY_ID = 'AKIA...'
$env:AWS_SECRET_ACCESS_KEY = '...'
```

2) Fill `terraform.tfvars` (local file already present as a placeholder) or pass variables on CLI. You must at minimum provide `sns_topic_arn` and `region_name` when calling the module from the root.

Example `terraform.tfvars` (DO NOT commit with real keys):

```
aws_profile = "myprofile"
region_name = "us-east-1"
sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:UnleashTopic"
```

3) Run Terraform

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

4) Test the endpoint (example)

```powershell
$api = "$(terraform output -raw api_endpoint)"
Invoke-RestMethod -Method Post -Uri "$api/greet" -Body (ConvertTo-Json @{message='hello'}) -ContentType 'application/json'
```

## Security and hygiene
- Never commit real credentials into the repository. Use `.gitignore` (already present).
- Terraform state can contain sensitive data. For production use, configure remote state in S3 with server-side encryption and state locking via DynamoDB.

## Next steps / TODOs
- Add a small dispatch worker that consumes SNS messages and performs further processing (if required).
- Integrate Cognito authorizers for API Gateway routes to enforce authenticated access.
