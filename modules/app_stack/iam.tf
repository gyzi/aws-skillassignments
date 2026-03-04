# ──────────────────────────────────────────────────────────────
# IAM Roles & Policies – Lambda + ECS
# ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ╔══════════════════════════════════════════════════════════╗
# ║  Lambda Execution Role                                   ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_iam_role" "lambda_role" {
  name = "app-stack-lambda-role-${local.region_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "app-stack-lambda-role-${local.region_suffix}" }
}

# ── Lambda base permissions (CloudWatch Logs + DynamoDB + SNS) ──
resource "aws_iam_policy" "lambda_base_policy" {
  name        = "app-stack-lambda-base-${local.region_suffix}"
  description = "Lambda: CloudWatch Logs, DynamoDB writes, SNS publish"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "DynamoDBWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
        ]
        Resource = aws_dynamodb_table.greeting_logs.arn
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn, var.verification_sns_arn]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_base_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_base_policy.arn
}

# ── Lambda ECS permissions (for Dispatcher) ──────────────────
resource "aws_iam_policy" "lambda_ecs_policy" {
  name        = "app-stack-lambda-ecs-${local.region_suffix}"
  description = "Lambda: run ECS Fargate tasks and pass IAM roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSRunTask"
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
        ]
        Resource = aws_ecs_task_definition.dispatcher_task.arn
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_task_execution_role.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ecs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ecs_policy.arn
}

# ╔══════════════════════════════════════════════════════════╗
# ║  ECS Task Execution Role (pulls images, writes logs)     ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "app-stack-ecs-exec-${local.region_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "app-stack-ecs-exec-${local.region_suffix}" }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ╔══════════════════════════════════════════════════════════╗
# ║  ECS Task Role (application permissions – SNS publish)   ║
# ╚══════════════════════════════════════════════════════════╝

resource "aws_iam_role" "ecs_task_role" {
  name = "app-stack-ecs-task-${local.region_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "app-stack-ecs-task-${local.region_suffix}" }
}

resource "aws_iam_role_policy" "ecs_task_sns" {
  name = "app-stack-ecs-task-sns-${local.region_suffix}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SNSPublish"
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = [var.sns_topic_arn, var.verification_sns_arn]
    }]
  })
}
