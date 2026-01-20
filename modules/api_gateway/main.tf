# API Gateway REST API für Chatbot

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_api_gateway_rest_api" "chatbot_api" {
  name        = "${var.project_name}-api"
  description = "API Gateway for AI Chatbot"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# /chat Resource
resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "chat"
}

# POST Method
resource "aws_api_gateway_method" "chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda Integration
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.chatbot_api.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# CORS - OPTIONS Method
resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS - Mock Integration
resource "aws_api_gateway_integration" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# CORS - Method Response
resource "aws_api_gateway_method_response" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# CORS - Integration Response
resource "aws_api_gateway_integration_response" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = aws_api_gateway_method_response.chat_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allow_origin
  }
}

# Deployment
resource "aws_api_gateway_deployment" "chatbot" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat.id,
      aws_api_gateway_method.chat_post.id,
      aws_api_gateway_integration.lambda.id,
      aws_api_gateway_resource.v1_chat_completions.id,
      aws_api_gateway_method.v1_completions_post.id,
      aws_api_gateway_integration.v1_completions_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.chat_options,
    aws_api_gateway_integration.v1_completions_lambda,
    aws_api_gateway_integration.v1_completions_options
  ]
}

# Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.chatbot.id
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  stage_name    = var.stage_name

  xray_tracing_enabled = var.enable_xray

  # Only configure access logs if destination ARN is provided
  dynamic "access_log_settings" {
    for_each = var.access_log_arn != "" && var.access_log_arn != null ? [1] : []
    content {
      destination_arn = var.access_log_arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
      })
    }
  }

  tags = {
    Name = "${var.project_name}-${var.stage_name}"
  }
}

# Usage Plan (Rate Limiting)
resource "aws_api_gateway_usage_plan" "chatbot" {
  name        = "${var.project_name}-usage-plan"
  description = "Usage plan with rate limiting"

  api_stages {
    api_id = aws_api_gateway_rest_api.chatbot_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  throttle_settings {
    burst_limit = var.burst_limit
    rate_limit  = var.rate_limit
  }

  quota_settings {
    limit  = var.quota_limit
    period = "MONTH"
  }

  tags = {
    Name = "${var.project_name}-usage-plan"
  }
}

# CloudWatch Log Group für Access Logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-api-logs"
  }
}

# ============================================
# OpenAI-Compatible API Routes
# /v1/chat/completions
# ============================================

# /v1 Resource
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_rest_api.chatbot_api.root_resource_id
  path_part   = "v1"
}

# /v1/chat Resource
resource "aws_api_gateway_resource" "v1_chat" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "chat"
}

# /v1/chat/completions Resource
resource "aws_api_gateway_resource" "v1_chat_completions" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  parent_id   = aws_api_gateway_resource.v1_chat.id
  path_part   = "completions"
}

# POST Method for /v1/chat/completions
resource "aws_api_gateway_method" "v1_completions_post" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.v1_chat_completions.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda Integration for /v1/chat/completions
resource "aws_api_gateway_integration" "v1_completions_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.chatbot_api.id
  resource_id             = aws_api_gateway_resource.v1_chat_completions.id
  http_method             = aws_api_gateway_method.v1_completions_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# OPTIONS Method for /v1/chat/completions (CORS)
resource "aws_api_gateway_method" "v1_completions_options" {
  rest_api_id   = aws_api_gateway_rest_api.chatbot_api.id
  resource_id   = aws_api_gateway_resource.v1_chat_completions.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock Integration for OPTIONS
resource "aws_api_gateway_integration" "v1_completions_options" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.v1_chat_completions.id
  http_method = aws_api_gateway_method.v1_completions_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method Response for OPTIONS
resource "aws_api_gateway_method_response" "v1_completions_options" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.v1_chat_completions.id
  http_method = aws_api_gateway_method.v1_completions_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "v1_completions_options" {
  rest_api_id = aws_api_gateway_rest_api.chatbot_api.id
  resource_id = aws_api_gateway_resource.v1_chat_completions.id
  http_method = aws_api_gateway_method.v1_completions_options.http_method
  status_code = aws_api_gateway_method_response.v1_completions_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allow_origin
  }
}
