# ──────────────────────────────────────────────────────────────
# DynamoDB – Regional GreetingLogs Table
# ──────────────────────────────────────────────────────────────

locals {
  region_suffix = replace(var.region, "-", "")
}

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs-${local.region_suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name   = "GreetingLogs-${local.region_suffix}"
    Region = var.region
  }
}
