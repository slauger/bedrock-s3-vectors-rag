# Lambda Function für Chatbot Handler (ZIP-based deployment)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

# Package Lambda function source code
data "archive_file" "lambda_zip" {
  count       = var.use_container_image ? 0 : 1
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_package.zip"
}

# IAM Role für Lambda
resource "aws_iam_role" "lambda_role" {
  count = var.use_container_image ? 0 : 1
  name  = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-role"
  }
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  count      = var.use_container_image ? 0 : 1
  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Bedrock Access Policy
resource "aws_iam_role_policy" "bedrock_access" {
  count = var.use_container_image ? 0 : 1
  name  = "${var.project_name}-bedrock-access"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Retrieve",
          "bedrock-agent-runtime:Retrieve",
          "bedrock-agent-runtime:RetrieveAndGenerate"
        ]
        Resource = "*"
      }
    ]
  })
}

# DynamoDB Access Policy
resource "aws_iam_role_policy" "dynamodb_access" {
  count = var.use_container_image ? 0 : 1
  name  = "${var.project_name}-dynamodb-access"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.dynamodb_table_arns
      }
    ]
  })
}

# S3 Vectors Access Policy
resource "aws_iam_role_policy" "s3_vectors_access" {
  count = var.use_container_image ? 0 : 1
  name  = "${var.project_name}-s3-vectors-access"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3vectors:GetVectorBucket",
          "s3vectors:GetIndex",
          "s3vectors:QueryVectors",
          "s3vectors:GetVectors"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  count             = var.use_container_image ? 0 : 1
  name              = "/aws/lambda/${var.project_name}-handler"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# Lambda Function
resource "aws_lambda_function" "chatbot_handler" {
  count            = var.use_container_image ? 0 : 1
  filename         = data.archive_file.lambda_zip[0].output_path
  function_name    = "${var.project_name}-handler"
  role             = aws_iam_role.lambda_role[0].arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256
  runtime          = "python3.12"
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = {
      MODEL_ID        = var.model_id
      SESSIONS_TABLE  = var.sessions_table_name
      MESSAGES_TABLE  = var.messages_table_name
      ANALYTICS_TABLE = var.analytics_table_name
      LOG_LEVEL       = var.log_level
      # S3 Vectors Configuration
      S3_VECTORS_BUCKET   = var.s3_vectors_bucket_name
      S3_VECTORS_INDEX    = var.s3_vectors_index_name
      BEDROCK_EMBED_MODEL = var.bedrock_embed_model
      KB_VERSION          = var.kb_version
      # AWS_REGION is automatically set by Lambda runtime - don't override
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-handler"
  }
}

# Lambda Permission für API Gateway
resource "aws_lambda_permission" "api_gateway" {
  count         = var.use_container_image ? 0 : 1
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot_handler[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_arn}/*/*"
}
