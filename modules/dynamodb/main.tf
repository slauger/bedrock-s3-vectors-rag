# DynamoDB Tables für Chatbot

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Sessions Table - Tracks user sessions
resource "aws_dynamodb_table" "sessions" {
  name         = "${var.project_name}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    enabled        = true
    attribute_name = "expire_at"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-sessions"
  }
}

# Messages Table - Stores conversation history
resource "aws_dynamodb_table" "messages" {
  name         = "${var.project_name}-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "timestamp"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  ttl {
    enabled        = true
    attribute_name = "expire_at"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-messages"
  }
}

# Analytics Table - Usage analytics and metrics
resource "aws_dynamodb_table" "analytics" {
  name         = "${var.project_name}-analytics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  range_key    = "timestamp"

  attribute {
    name = "event_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # GSI for querying by date range
  global_secondary_index {
    name            = "TimestampIndex"
    hash_key        = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    enabled        = true
    attribute_name = "expire_at"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-analytics"
  }
}
