# ──────────────────────────────────────────────────────────────
# API Gateway v2 (HTTP API) + Cognito JWT Authorizer
# ──────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "http_api" {
  name          = "app-stack-api-${local.region_suffix}"
  protocol_type = "HTTP"

  tags = { Name = "app-stack-api-${local.region_suffix}" }
}

# ── Cognito JWT Authorizer ───────────────────────────────────
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http_api.id
  name             = "cognito-jwt-authorizer"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.cognito_user_pool_client_id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

# ── Integrations ─────────────────────────────────────────────
resource "aws_apigatewayv2_integration" "greet" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.greet.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "dispatch" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dispatch.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# ── Routes (protected by Cognito authorizer) ─────────────────
resource "aws_apigatewayv2_route" "greet" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /greet"
  target    = "integrations/${aws_apigatewayv2_integration.greet.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "dispatch" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /dispatch"
  target    = "integrations/${aws_apigatewayv2_integration.dispatch.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# ── Default Stage (auto-deploy) ──────────────────────────────
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/apigateway/app-stack-${local.region_suffix}"
  retention_in_days = 14

  tags = { Name = "api-access-logs-${local.region_suffix}" }
}

# ── Lambda Invoke Permissions ────────────────────────────────
resource "aws_lambda_permission" "apigw_greet" {
  statement_id  = "AllowAPIGatewayInvokeGreet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greet.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/greet"
}

resource "aws_lambda_permission" "apigw_dispatch" {
  statement_id  = "AllowAPIGatewayInvokeDispatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatch.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/dispatch"
}
