variable "project_name" {
  description = "Project name prefix (e.g., 'my-chatbot')"
  type        = string
}

variable "s3_vectors_bucket_name" {
  description = "S3 bucket name for vector storage (e.g., 'my-vectors-bucket')"
  type        = string
}

variable "s3_vectors_index_name" {
  description = "S3 Vectors index name"
  type        = string
  default     = "kb-index"
}

variable "bedrock_embed_model" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "model_id" {
  description = "Bedrock Model ID"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "sessions_table_name" {
  description = "DynamoDB sessions table name"
  type        = string
}

variable "messages_table_name" {
  description = "DynamoDB messages table name"
  type        = string
}

variable "analytics_table_name" {
  description = "DynamoDB analytics table name"
  type        = string
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs for IAM policy"
  type        = list(string)
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Log level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

variable "api_gateway_arn" {
  description = "API Gateway ARN for Lambda permission"
  type        = string
  default     = ""
}

variable "use_container_image" {
  description = "Use container image instead of ZIP deployment"
  type        = bool
  default     = false
}

variable "kb_version" {
  description = "Knowledge Base version for tracking updates"
  type        = string
  default     = "unknown"
}
