variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool (not used directly in this module but kept for reference/permissions)"
  type        = string
}

variable "region_name" {
  description = "Region name where resources will be created"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS Topic ARN where greet messages will be published"
  type        = string
}
