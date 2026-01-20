variable "project_name" {
  description = "Project name prefix for resources (e.g., 'my-chatbot')"
  type        = string
}

variable "enable_pitr" {
  description = "Enable Point-in-Time Recovery for DynamoDB tables"
  type        = bool
  default     = false
}
