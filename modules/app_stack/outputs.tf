output "dynamodb_table_name" {
  value = aws_dynamodb_table.greeting_logs.name
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "greet_lambda_arn" {
  value = aws_lambda_function.greet.arn
}
