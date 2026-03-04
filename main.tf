# ──────────────────────────────────────────────────────────────
# Root Module – Cognito (us-east-1) + Multi-Region App Stacks
# ──────────────────────────────────────────────────────────────

locals {
  # Unleash Live verification SNS topic (cross-account, us-east-1)
  verification_sns_arn = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
}

# ╔══════════════════════════════════════════════════════════╗
# ║  1. Cognito User Pool & Client  (us-east-1 only)        ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_cognito_user_pool" "central" {
  provider = aws.us_east_1
  name     = "ai-video-analytics-user-pool"

  auto_verified_attributes = ["email"]
  alias_attributes         = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  tags = { Name = "ai-video-analytics-user-pool" }
}

resource "aws_cognito_user_pool_client" "app_client" {
  provider     = aws.us_east_1
  name         = "ai-video-analytics-app-client"
  user_pool_id = aws_cognito_user_pool.central.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user" "test_user" {
  provider     = aws.us_east_1
  user_pool_id = aws_cognito_user_pool.central.id
  username     = "testuser"

  attributes = {
    email          = var.email
    email_verified = "true"
  }
}

# ╔══════════════════════════════════════════════════════════╗
# ║  2. SNS Topic  (us-east-1, shared by both regions)      ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_sns_topic" "notifications" {
  provider = aws.us_east_1
  name     = "app-stack-notifications"

  tags = { Name = "app-stack-notifications" }
}

resource "aws_sns_topic_subscription" "email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.email
}

# ╔══════════════════════════════════════════════════════════╗
# ║  3. Application Stack – us-east-1                        ║
# ╚══════════════════════════════════════════════════════════╝

module "app_us_east" {
  source    = "./modules/app_stack"
  providers = { aws = aws.us_east_1 }

  region                      = var.aws_region_us_east
  environment                 = var.environment
  sns_topic_arn               = aws_sns_topic.notifications.arn
  verification_sns_arn        = local.verification_sns_arn
  email                       = var.email
  github_repo                 = var.github_repo
  cognito_user_pool_arn       = aws_cognito_user_pool.central.arn
  cognito_user_pool_id        = aws_cognito_user_pool.central.id
  cognito_user_pool_client_id = aws_cognito_user_pool_client.app_client.id
}

# ╔══════════════════════════════════════════════════════════╗
# ║  4. Application Stack – eu-west-1                        ║
# ╚══════════════════════════════════════════════════════════╝

module "app_eu_west" {
  source    = "./modules/app_stack"
  providers = { aws = aws.eu_west_1 }

  region                      = var.aws_region_eu_west
  environment                 = var.environment
  sns_topic_arn               = aws_sns_topic.notifications.arn
  verification_sns_arn        = local.verification_sns_arn
  email                       = var.email
  github_repo                 = var.github_repo
  cognito_user_pool_arn       = aws_cognito_user_pool.central.arn
  cognito_user_pool_id        = aws_cognito_user_pool.central.id
  cognito_user_pool_client_id = aws_cognito_user_pool_client.app_client.id
}

# ╔══════════════════════════════════════════════════════════╗
# ║  4. Outputs                                              ║
# ╚══════════════════════════════════════════════════════════╝

# ── Cognito ──────────────────────────────────────────────────
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID (us-east-1)"
  value       = aws_cognito_user_pool.central.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito App Client ID (us-east-1)"
  value       = aws_cognito_user_pool_client.app_client.id
}

# ── us-east-1 ────────────────────────────────────────────────
output "api_endpoint_us_east" {
  description = "HTTP API endpoint – us-east-1"
  value       = module.app_us_east.api_endpoint
}

output "ecs_cluster_us_east" {
  description = "ECS cluster name – us-east-1"
  value       = module.app_us_east.ecs_cluster_name
}

# ── eu-west-1 ────────────────────────────────────────────────
output "api_endpoint_eu_west" {
  description = "HTTP API endpoint – eu-west-1"
  value       = module.app_eu_west.api_endpoint
}

output "ecs_cluster_eu_west" {
  description = "ECS cluster name – eu-west-1"
  value       = module.app_eu_west.ecs_cluster_name
}
