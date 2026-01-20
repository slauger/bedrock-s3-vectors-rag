variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "kb_bucket_arn" {
  description = "ARN of the knowledge base S3 bucket"
  type        = string
}

variable "website_bucket_arn" {
  description = "ARN of the website S3 bucket"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Bedrock resources"
  type        = string
  default     = "eu-central-1"
}
