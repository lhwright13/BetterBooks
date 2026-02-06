# BetterBooks Secrets Module
# Creates AWS Secrets Manager secrets for sensitive configuration

resource "aws_secretsmanager_secret" "main" {
  name        = "${var.project_name}/${var.environment}"
  description = "BetterBooks application secrets"

  # Allow recovery for 7 days (minimum)
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "main" {
  secret_id = aws_secretsmanager_secret.main.id

  secret_string = jsonencode({
    JWT_SECRET_KEY = var.jwt_secret_key
    # Add other secrets as needed
    # AZURE_OPENAI_API_KEY = var.azure_openai_api_key
  })
}

# IAM policy for ECS tasks to read secrets
resource "aws_iam_policy" "secrets_read" {
  name        = "${var.project_name}-${var.environment}-secrets-read"
  description = "Allow reading BetterBooks secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.main.arn
      }
    ]
  })
}
