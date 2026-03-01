# ──────────────────────────────────────────────────────────────
# Module: app_stack – Input Variables
# ──────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region where this stack is deployed"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for verification messages"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the central Cognito User Pool (for IAM scoping)"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID of the central Cognito User Pool (for JWT authorizer)"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool App Client (for JWT audience)"
  type        = string
}

variable "email" {
  description = "Email address for the SNS verification payload"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL for the SNS verification payload"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout in seconds for Lambda functions"
  type        = number
  default     = 30
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.12"
}

variable "fargate_cpu" {
  description = "CPU units for Fargate task (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "fargate_memory" {
  description = "Memory (MiB) for Fargate task"
  type        = string
  default     = "512"
}
