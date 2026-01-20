variable "project_name" {
  description = "Project name prefix (e.g., 'my-chatbot')"
  type        = string
}

variable "kb_data_bucket_name" {
  description = "S3 bucket name for knowledge base data (if not set, uses project_name-kb-data)"
  type        = string
  default     = ""
}

variable "vector_bucket_name" {
  description = "S3 bucket name for vector storage (if not set, uses project_name-vector-bucket)"
  type        = string
  default     = ""
}

variable "version_retention_days" {
  description = "Number of days to retain old S3 object versions"
  type        = number
  default     = 30
}

variable "create_website_bucket" {
  description = "Whether to create a website hosting bucket"
  type        = bool
  default     = false
}
