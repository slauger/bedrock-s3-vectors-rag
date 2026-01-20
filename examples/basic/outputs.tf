# Basic example outputs

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.invoke_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "vector_bucket_name" {
  description = "S3 bucket name for vector storage"
  value       = module.s3.vector_bucket_name
}

output "kb_data_bucket_name" {
  description = "S3 bucket name for knowledge base data"
  value       = module.s3.kb_data_bucket_name
}

output "sessions_table_name" {
  description = "DynamoDB sessions table name"
  value       = module.dynamodb.sessions_table_name
}

output "messages_table_name" {
  description = "DynamoDB messages table name"
  value       = module.dynamodb.messages_table_name
}

output "analytics_table_name" {
  description = "DynamoDB analytics table name"
  value       = module.dynamodb.analytics_table_name
}
