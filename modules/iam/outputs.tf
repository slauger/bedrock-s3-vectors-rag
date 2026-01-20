output "user_name" {
  description = "GitHub Actions IAM user name"
  value       = aws_iam_user.github_actions.name
}

output "user_arn" {
  description = "GitHub Actions IAM user ARN"
  value       = aws_iam_user.github_actions.arn
}

output "access_key_id" {
  description = "Access key ID for GitHub Actions (save as GitHub Secret: AWS_ACCESS_KEY_ID)"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret access key for GitHub Actions (save as GitHub Secret: AWS_SECRET_ACCESS_KEY)"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}
