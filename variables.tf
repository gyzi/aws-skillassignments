# ──────────────────────────────────────────────────────────────
# Root Variables
# ──────────────────────────────────────────────────────────────

variable "aws_profile" {
  description = "AWS CLI named profile (from ~/.aws/credentials). Leave empty to use the default credential chain."
  type        = string
  default     = ""
}

variable "aws_region_us_east" {
  description = "Primary region (hosts Cognito + app stack)"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_eu_west" {
  description = "Secondary region (app stack only)"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ── Application-specific (required – set in terraform.tfvars) ──

variable "email" {
  description = "Email used for the Cognito test user and the SNS verification payload"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository URL included in the SNS verification payload"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic that the Greeter Lambda publishes verification messages to"
  type        = string
}