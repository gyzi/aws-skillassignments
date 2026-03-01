# ──────────────────────────────────────────────────────────────
# Module Outputs
# ──────────────────────────────────────────────────────────────

output "api_endpoint" {
  description = "HTTP API invoke URL"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "api_id" {
  description = "HTTP API Gateway ID"
  value       = aws_apigatewayv2_api.http_api.id
}

output "dynamodb_table_name" {
  description = "Regional DynamoDB table name"
  value       = aws_dynamodb_table.greeting_logs.name
}

output "greet_lambda_arn" {
  description = "Greeter Lambda function ARN"
  value       = aws_lambda_function.greet.arn
}

output "dispatch_lambda_arn" {
  description = "Dispatcher Lambda function ARN"
  value       = aws_lambda_function.dispatch.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.app_cluster.name
}

output "ecs_task_definition_arn" {
  description = "Fargate dispatcher task definition ARN"
  value       = aws_ecs_task_definition.dispatcher_task.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.app.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by Fargate tasks"
  value       = aws_subnet.public[*].id
}
