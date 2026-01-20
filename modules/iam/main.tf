terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# IAM User for GitHub Actions
resource "aws_iam_user" "github_actions" {
  name = "${var.project_name}-github-actions"

  tags = {
    Name        = "GitHub Actions CI/CD User"
    Description = "IAM user for GitHub Actions to deploy website and update knowledge base"
  }
}

# Access Keys for GitHub Actions
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

# Policy for S3 Knowledge Base access
resource "aws_iam_user_policy" "knowledge_base_access" {
  name = "${var.project_name}-kb-s3-access"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.kb_bucket_arn,
          "${var.kb_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Policy for S3 Website access
resource "aws_iam_user_policy" "website_access" {
  name = "${var.project_name}-website-s3-access"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ]
        Resource = [
          var.website_bucket_arn,
          "${var.website_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Policy for Bedrock Knowledge Base Ingestion
resource "aws_iam_user_policy" "bedrock_ingestion_access" {
  name = "${var.project_name}-bedrock-ingestion-access"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob",
          "bedrock:ListIngestionJobs"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:knowledge-base/*"
        ]
      }
    ]
  })
}
