# Secrets Module Outputs

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.main.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.main.name
}

output "secrets_read_policy_arn" {
  description = "ARN of the IAM policy for reading secrets"
  value       = aws_iam_policy.secrets_read.arn
}
