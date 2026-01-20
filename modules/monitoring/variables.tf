variable "project_name" {
  description = "Project name prefix (e.g., 'my-chatbot')"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name to monitor"
  type        = string
}

variable "api_gateway_name" {
  description = "API Gateway name to monitor"
  type        = string
  default     = ""
}

variable "dynamodb_table_names" {
  description = "List of DynamoDB table names to monitor"
  type        = list(string)
  default     = []
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}
