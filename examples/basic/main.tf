# Basic example using S3 Vectors for RAG with AWS Bedrock

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# DynamoDB Tables for session/message storage
module "dynamodb" {
  source = "../../modules/dynamodb"

  project_name = var.project_name
  enable_pitr  = var.enable_pitr
}

# S3 Buckets for KB data and vectors
module "s3" {
  source = "../../modules/s3"

  project_name          = var.project_name
  vector_bucket_name    = "${var.project_name}-vector-bucket"
  kb_data_bucket_name   = "${var.project_name}-kb-data"
  create_website_bucket = false
}

# Lambda Function for chatbot handler
module "lambda" {
  source = "../../modules/lambda"

  project_name           = var.project_name
  model_id               = var.bedrock_model_id
  s3_vectors_bucket_name = module.s3.vector_bucket_name
  s3_vectors_index_name  = var.s3_vectors_index_name
  bedrock_embed_model    = var.bedrock_embed_model
  sessions_table_name    = module.dynamodb.sessions_table_name
  messages_table_name    = module.dynamodb.messages_table_name
  analytics_table_name   = module.dynamodb.analytics_table_name
  dynamodb_table_arns    = module.dynamodb.table_arns
  api_gateway_arn        = module.api_gateway.execution_arn
  use_container_image    = false
  kb_version             = var.kb_version
  timeout                = var.lambda_timeout
  memory_size            = var.lambda_memory_size
  log_level              = var.log_level
  log_retention_days     = var.log_retention_days
}

# API Gateway for REST API
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name       = var.project_name
  lambda_invoke_arn  = module.lambda.invoke_arn
  stage_name         = var.api_stage_name
  cors_allow_origin  = var.cors_allow_origin
  burst_limit        = var.api_burst_limit
  rate_limit         = var.api_rate_limit
  quota_limit        = var.api_quota_limit
  log_retention_days = var.log_retention_days
}

# CloudWatch Monitoring (optional)
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "../../modules/monitoring"

  project_name         = var.project_name
  lambda_function_name = module.lambda.function_name
  api_gateway_name     = module.api_gateway.api_name
  dynamodb_table_names = [
    module.dynamodb.sessions_table_name,
    module.dynamodb.messages_table_name,
    module.dynamodb.analytics_table_name
  ]
  alarm_email = var.alarm_email
}
