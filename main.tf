resource "aws_cognito_user_pool" "central" {
  provider = aws.us_east_1
  name     = "central-user-pool"

  auto_verified_attributes = ["email"]
  alias_attributes         = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
  }
}

resource "aws_cognito_user_pool_client" "app_client" {
  provider     = aws.us_east_1
  name         = "central-app-client"
  user_pool_id = aws_cognito_user_pool.central.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user" "test_user" {
  provider     = aws.us_east_1
  user_pool_id = aws_cognito_user_pool.central.id
  username     = "your_email@example.com"

  attributes = {
    email          = "your_email@example.com"
    email_verified = "true"
  }

  # Note: not setting a password here because passwords (including temporary)
  # are stored in state. If you want to set a temporary password, use the
  # temporary_password attribute but be aware it will be in plaintext in state.
}

output "user_pool_id" {
  value = aws_cognito_user_pool.central.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.app_client.id
}
