locals {
  lambda_source_dir = "$${path.module}/lambda"
}

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "GreetingLogs"
  }
}

data "archive_file" "greet_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/greet.py"
  output_path = "${path.module}/lambda/greet.zip"
}

data "archive_file" "dispatch_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/dispatch.py"
  output_path = "${path.module}/lambda/dispatch.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "app_stack_lambda_role-${replace(var.region, "-", "")}" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "app_stack_lambda_policy-${replace(var.region, "-", "")}" 
  description = "Permissions for Lambda to write to DynamoDB and publish to SNS and write CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.greeting_logs.arn
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "greet" {
  filename         = data.archive_file.greet_zip.output_path
  function_name    = "app_stack_greet_${replace(var.region, "-", "") }"
  role             = aws_iam_role.lambda_role.arn
  handler          = "greet.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.greet_zip.output_base64sha256

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.greeting_logs.name
      SNS_ARN   = var.sns_topic_arn
  REGION    = var.region
    }
  }
}

resource "aws_lambda_function" "dispatch" {
  filename         = data.archive_file.dispatch_zip.output_path
  function_name    = "app_stack_dispatch_${replace(var.region, "-", "") }"
  role             = aws_iam_role.lambda_role.arn
  handler          = "dispatch.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.dispatch_zip.output_base64sha256
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "app-stack-http-api-${replace(var.region, "-", "") }"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "greet_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.greet.arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "dispatch_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.dispatch.arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "greet_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /greet"
  target    = "integrations/${aws_apigatewayv2_integration.greet_integration.id}"
}

resource "aws_apigatewayv2_route" "dispatch_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /dispatch"
  target    = "integrations/${aws_apigatewayv2_integration.dispatch_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke_greet" {
  statement_id  = "AllowAPIGatewayInvokeGreet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greet.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:*:${aws_apigatewayv2_api.http_api.id}/*/POST/greet"
}

resource "aws_lambda_permission" "apigw_invoke_dispatch" {
  statement_id  = "AllowAPIGatewayInvokeDispatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatch.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:*:${aws_apigatewayv2_api.http_api.id}/*/POST/dispatch"
}
