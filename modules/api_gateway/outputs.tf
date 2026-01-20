output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.chatbot_api.id
}

output "api_arn" {
  description = "API Gateway Execution ARN for Lambda permissions"
  value       = aws_api_gateway_rest_api.chatbot_api.execution_arn
}

output "api_endpoint" {
  description = "API Gateway invoke URL"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/chat"
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.prod.stage_name
}

output "usage_plan_id" {
  description = "Usage plan ID"
  value       = aws_api_gateway_usage_plan.chatbot.id
}
