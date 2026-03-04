# ──────────────────────────────────────────────────────────────
# ECS Fargate – Dispatcher Task (Cost-Optimized)
# ──────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "app_cluster" {
  name = "app-stack-cluster-${local.region_suffix}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "app-stack-cluster-${local.region_suffix}" }
}

# ── CloudWatch Logs for Fargate tasks ────────────────────────
resource "aws_cloudwatch_log_group" "dispatcher" {
  name              = "/ecs/dispatcher-${local.region_suffix}"
  retention_in_days = 7

  tags = { Name = "ecs-dispatcher-logs-${local.region_suffix}" }
}

# ── Security Group (egress-only – Fargate needs outbound) ────
resource "aws_security_group" "ecs_tasks" {
  name        = "app-stack-ecs-tasks-${local.region_suffix}"
  description = "Fargate tasks - allow all egress for AWS API calls"
  vpc_id      = aws_vpc.app.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "app-stack-ecs-sg-${local.region_suffix}" }
}

# ── Fargate Task Definition (amazon/aws-cli → SNS publish) ──
resource "aws_ecs_task_definition" "dispatcher_task" {
  family                   = "app-stack-dispatcher-${local.region_suffix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name       = "aws-cli"
      image      = "amazon/aws-cli:latest"
      essential  = true
      entryPoint = ["sh", "-c"]

      # Build verification payload and publish to Unleash Live + own topic
      command = [
        join(" && ", [
          "MSG=$(printf '{\"email\":\"%s\",\"source\":\"ECS\",\"region\":\"%s\",\"repo\":\"%s\"}' \"$EMAIL\" \"$REGION\" \"$GITHUB_REPO\")",
          "echo \"Publishing: $MSG\"",
          "aws sns publish --topic-arn \"$VERIFICATION_SNS_ARN\" --message \"$MSG\" --region us-east-1",
          "aws sns publish --topic-arn \"$SNS_TOPIC_ARN\" --message \"$MSG\" --region \"$REGION\"",
        ])
      ]

      environment = [
        { name = "VERIFICATION_SNS_ARN", value = var.verification_sns_arn },
        { name = "SNS_TOPIC_ARN", value = var.sns_topic_arn },
        { name = "EMAIL", value = var.email },
        { name = "GITHUB_REPO", value = var.github_repo },
        { name = "REGION", value = var.region },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dispatcher.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "dispatcher"
        }
      }
    }
  ])

  tags = { Name = "app-stack-dispatcher-task-${local.region_suffix}" }
}
