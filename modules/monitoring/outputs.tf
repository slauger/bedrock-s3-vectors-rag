output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "lambda_error_alarm_arn" {
  description = "Lambda error alarm ARN"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}

output "lambda_latency_alarm_arn" {
  description = "Lambda latency alarm ARN"
  value       = aws_cloudwatch_metric_alarm.lambda_latency.arn
}
