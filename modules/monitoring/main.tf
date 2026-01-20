# CloudWatch Monitoring & Alarms

# SNS Topic für Alarm Notifications
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"

  tags = {
    Name = "${var.project_name}-alarms"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-high-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda error rate too high"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-errors"
  }
}

# Lambda High Latency Alarm (P95)
resource "aws_cloudwatch_metric_alarm" "lambda_latency" {
  alarm_name          = "${var.project_name}-lambda-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 5000 # 5 seconds
  alarm_description   = "Lambda P95 latency too high"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-latency"
  }
}

# Lambda Throttles Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda throttling detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-throttles"
  }
}

# API Gateway 5XX Errors
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  count               = var.api_gateway_name != "" ? 1 : 0
  alarm_name          = "${var.project_name}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5XX error rate too high"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = {
    Name = "${var.project_name}-api-5xx"
  }
}

# API Gateway High Latency
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  count               = var.api_gateway_name != "" ? 1 : 0
  alarm_name          = "${var.project_name}-api-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 3000 # 3 seconds
  alarm_description   = "API Gateway P95 latency too high"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = var.api_gateway_name
  }

  tags = {
    Name = "${var.project_name}-api-latency"
  }
}

# DynamoDB Read Throttles
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  count               = length(var.dynamodb_table_names)
  alarm_name          = "${var.project_name}-dynamodb-read-throttles-${element(var.dynamodb_table_names, count.index)}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "DynamoDB read throttling detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    TableName = element(var.dynamodb_table_names, count.index)
  }

  tags = {
    Name = "${var.project_name}-dynamodb-read-throttles"
  }
}
