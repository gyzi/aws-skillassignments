# ──────────────────────────────────────────────────────────────
# Module: app_stack – Required Providers
# ──────────────────────────────────────────────────────────────
# This block tells Terraform which provider configurations
# this module expects to receive from the calling module.
# It silences the "Reference to undefined provider" warning.

terraform {
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
