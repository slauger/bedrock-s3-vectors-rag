output "kb_data_bucket_name" {
  description = "S3 bucket name for knowledge base data"
  value       = aws_s3_bucket.kb_data.id
}

output "kb_data_bucket_arn" {
  description = "S3 bucket ARN for knowledge base data"
  value       = aws_s3_bucket.kb_data.arn
}

output "vector_bucket_name" {
  description = "S3 bucket name for vector storage (same as kb_data for now)"
  value       = local.vector_bucket_name
}

output "website_bucket_name" {
  description = "S3 bucket name for website (if enabled)"
  value       = var.create_website_bucket ? aws_s3_bucket.website[0].id : null
}

output "website_bucket_arn" {
  description = "S3 bucket ARN for website (if enabled)"
  value       = var.create_website_bucket ? aws_s3_bucket.website[0].arn : null
}

output "website_endpoint" {
  description = "S3 website endpoint URL (if enabled)"
  value       = var.create_website_bucket ? aws_s3_bucket_website_configuration.website[0].website_endpoint : null
}

output "bedrock_kb_role_arn" {
  description = "IAM role ARN for Bedrock Knowledge Base"
  value       = aws_iam_role.bedrock_kb_role.arn
}
