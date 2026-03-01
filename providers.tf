# ──────────────────────────────────────────────────────────────
# Terraform & Provider Configuration
# ──────────────────────────────────────────────────────────────
# Authentication: use AWS_PROFILE env var or aws configure.
# Do NOT hardcode credentials in .tf or .tfvars files.
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# ── Primary region (us-east-1) – also hosts Cognito ─────────
provider "aws" {
  alias   = "us_east_1"
  region  = var.aws_region_us_east
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = "ai-video-analytics"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# ── Secondary region (eu-west-1) ────────────────────────────
provider "aws" {
  alias   = "eu_west_1"
  region  = var.aws_region_eu_west
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = "ai-video-analytics"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
