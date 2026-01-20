# S3 Bucket für Bedrock Knowledge Base Daten

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  kb_bucket_name     = var.kb_data_bucket_name != "" ? var.kb_data_bucket_name : "${var.project_name}-kb-data"
  vector_bucket_name = var.vector_bucket_name != "" ? var.vector_bucket_name : "${var.project_name}-vector-bucket"
}

resource "aws_s3_bucket" "kb_data" {
  bucket = local.kb_bucket_name

  tags = {
    Name = local.kb_bucket_name
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "kb_data" {
  bucket = aws_s3_bucket.kb_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "kb_data" {
  bucket = aws_s3_bucket.kb_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "kb_data" {
  bucket = aws_s3_bucket.kb_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rule (delete old versions)
resource "aws_s3_bucket_lifecycle_configuration" "kb_data" {
  bucket = aws_s3_bucket.kb_data.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {} # Apply to all objects

    noncurrent_version_expiration {
      noncurrent_days = var.version_retention_days
    }
  }

  rule {
    id     = "delete-incomplete-multipart"
    status = "Enabled"

    filter {} # Apply to all objects

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# IAM Role für Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_kb_role" {
  name = "${var.project_name}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-bedrock-kb-role"
  }
}

# S3 Access Policy für Bedrock
resource "aws_iam_role_policy" "bedrock_s3_access" {
  name = "${var.project_name}-bedrock-s3-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.kb_data.arn,
          "${aws_s3_bucket.kb_data.arn}/*"
        ]
      }
    ]
  })
}

# S3 Bucket für Website Hosting (optional)
resource "aws_s3_bucket" "website" {
  count  = var.create_website_bucket ? 1 : 0
  bucket = "${var.project_name}-website"

  tags = {
    Name = "${var.project_name}-website"
  }
}

# Website Configuration
resource "aws_s3_bucket_website_configuration" "website" {
  count  = var.create_website_bucket ? 1 : 0
  bucket = aws_s3_bucket.website[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "website" {
  count  = var.create_website_bucket ? 1 : 0
  bucket = aws_s3_bucket.website[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  count  = var.create_website_bucket ? 1 : 0
  bucket = aws_s3_bucket.website[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public Access (Website needs public read)
resource "aws_s3_bucket_public_access_block" "website" {
  count  = var.create_website_bucket ? 1 : 0
  bucket = aws_s3_bucket.website[0].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy for Public Read
resource "aws_s3_bucket_policy" "website" {
  count  = var.create_website_bucket ? 1 : 0
  bucket = aws_s3_bucket.website[0].id

  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website[0].arn}/*"
      }
    ]
  })
}
