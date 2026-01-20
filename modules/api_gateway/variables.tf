variable "project_name" {
  description = "Project name prefix (e.g., 'my-chatbot')"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda function invoke ARN"
  type        = string
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "cors_allow_origin" {
  description = "CORS allow origin header value"
  type        = string
  default     = "'*'"
}

variable "burst_limit" {
  description = "API Gateway burst limit (requests per second)"
  type        = number
  default     = 20
}

variable "rate_limit" {
  description = "API Gateway rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "quota_limit" {
  description = "Monthly quota limit (total requests)"
  type        = number
  default     = 10000
}

variable "enable_xray" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "access_log_arn" {
  description = "CloudWatch log group ARN for access logs"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
