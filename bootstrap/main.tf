# ──────────────────────────────────────────────────────────────
# Bootstrap – GitHub Actions OIDC → AWS
# ──────────────────────────────────────────────────────────────
# Run ONCE from this directory before the CI/CD pipeline works:
#
#   cd bootstrap
#   terraform init
#   terraform apply
#
# Then copy the output role ARN to your GitHub secret AWS_ROLE_ARN.
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project   = "ai-video-analytics"
      ManagedBy = "terraform"
      Purpose   = "github-actions-oidc-bootstrap"
    }
  }
}

# ── Variables ─────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for the OIDC provider"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile (leave empty to use default chain)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository in 'owner/repo' format"
  type        = string
  default     = "gyzi/aws-skillassignments"
}

# ── OIDC Identity Provider ────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# ── IAM Role for GitHub Actions ───────────────────────────────

resource "aws_iam_role" "github_actions" {
  name        = "github-actions-terraform-role"
  description = "Allows GitHub Actions to manage AWS resources via OIDC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── Outputs ───────────────────────────────────────────────────

output "role_arn" {
  description = "Copy this value to your GitHub secret: AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (for reference)"
  value       = aws_iam_openid_connect_provider.github.arn
}
