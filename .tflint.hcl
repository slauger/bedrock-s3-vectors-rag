# TFLint Configuration for bedrock-s3-vectors-rag

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Rule Configuration
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

# AWS-specific rules
rule "aws_resource_missing_tags" {
  enabled = false  # We use tags selectively
}

rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  # Not needed for standard AWS
}

rule "aws_iam_role_policy_too_long" {
  enabled = true
}

rule "aws_lambda_function_deprecated_runtime" {
  enabled = true
}

rule "aws_s3_bucket_versioning_enabled" {
  enabled = false  # We configure this per bucket
}
