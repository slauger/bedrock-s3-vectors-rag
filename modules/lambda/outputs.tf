output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.chatbot_handler[0].function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.chatbot_handler[0].arn
}

output "invoke_arn" {
  description = "Lambda invoke ARN for API Gateway"
  value       = aws_lambda_function.chatbot_handler[0].invoke_arn
}

output "role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda_role[0].arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda_logs[0].name
}
