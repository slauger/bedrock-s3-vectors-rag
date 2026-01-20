# Basic example variables

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "my-chatbot"
}

variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# Bedrock Configuration
variable "bedrock_model_id" {
  description = "Bedrock LLM model ID"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "bedrock_embed_model" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

# S3 Vectors Configuration
variable "s3_vectors_index_name" {
  description = "S3 Vectors index name"
  type        = string
  default     = "kb-index"
}

variable "kb_version" {
  description = "Knowledge Base version for tracking updates"
  type        = string
  default     = "1.0.0"
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "log_level" {
  description = "Log level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# DynamoDB Configuration
variable "enable_pitr" {
  description = "Enable Point-in-Time Recovery for DynamoDB"
  type        = bool
  default     = false
}

# API Gateway Configuration
variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "cors_allow_origin" {
  description = "CORS allow origin header value"
  type        = string
  default     = "'*'"
}

variable "api_burst_limit" {
  description = "API Gateway burst limit (requests per second)"
  type        = number
  default     = 20
}

variable "api_rate_limit" {
  description = "API Gateway rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "api_quota_limit" {
  description = "Monthly quota limit (total requests)"
  type        = number
  default     = 10000
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}
