terraform {
  required_version = ">= 1.11.0"
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

provider "aws" {
  alias      = "us_east_1"
  region     = var.aws_region_us_east

  # Prefer profile or env vars — provide access/secret/profile via variables
  # If a variable is empty, we pass null so the AWS provider falls back to
  # the standard credential chain (env vars, shared credentials file, etc.).
  profile    = var.aws_profile != "" ? var.aws_profile : null
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null
}

provider "aws" {
  alias      = "eu_west_1"
  region     = var.aws_region_eu_west

  profile    = var.aws_profile != "" ? var.aws_profile : null
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null
}
