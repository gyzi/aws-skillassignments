# ──────────────────────────────────────────────────────────────
# Lambda Functions – Greeter & Dispatcher
# ──────────────────────────────────────────────────────────────

# ── Package Lambda source code ───────────────────────────────
data "archive_file" "greet_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/greet.py"
  output_path = "${path.module}/lambda/.build/greet.zip"
}

data "archive_file" "dispatch_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/dispatch.py"
  output_path = "${path.module}/lambda/.build/dispatch.zip"
}

# ╔══════════════════════════════════════════════════════════╗
# ║  Lambda 1 – Greeter  (POST /greet)                      ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_lambda_function" "greet" {
  function_name    = "app-stack-greet-${local.region_suffix}"
  filename         = data.archive_file.greet_zip.output_path
  source_code_hash = data.archive_file.greet_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "greet.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout

  environment {
    variables = {
      DDB_TABLE   = aws_dynamodb_table.greeting_logs.name
      SNS_ARN     = var.sns_topic_arn
      REGION      = var.region
      EMAIL       = var.email
      GITHUB_REPO = var.github_repo
    }
  }

  tags = { Name = "app-stack-greet-${local.region_suffix}" }
}

# ╔══════════════════════════════════════════════════════════╗
# ║  Lambda 2 – Dispatcher  (POST /dispatch)                 ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_lambda_function" "dispatch" {
  function_name    = "app-stack-dispatch-${local.region_suffix}"
  filename         = data.archive_file.dispatch_zip.output_path
  source_code_hash = data.archive_file.dispatch_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "dispatch.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout

  environment {
    variables = {
      REGION         = var.region
      ECS_CLUSTER    = aws_ecs_cluster.app_cluster.name
      ECS_TASK_DEF   = aws_ecs_task_definition.dispatcher_task.arn
      PUBLIC_SUBNETS = join(",", aws_subnet.public[*].id)
      ECS_SG         = aws_security_group.ecs_tasks.id
    }
  }

  tags = { Name = "app-stack-dispatch-${local.region_suffix}" }
}
