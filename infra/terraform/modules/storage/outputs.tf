# Storage Module Outputs

output "audiobooks_bucket_name" {
  description = "Name of the audiobooks S3 bucket"
  value       = aws_s3_bucket.audiobooks.id
}

output "audiobooks_bucket_arn" {
  description = "ARN of the audiobooks S3 bucket"
  value       = aws_s3_bucket.audiobooks.arn
}

output "static_bucket_name" {
  description = "Name of the static assets S3 bucket"
  value       = aws_s3_bucket.static.id
}

output "static_website_endpoint" {
  description = "S3 static website endpoint"
  value       = aws_s3_bucket_website_configuration.static.website_endpoint
}

output "static_website_url" {
  description = "Full URL for static website"
  value       = "http://${aws_s3_bucket_website_configuration.static.website_endpoint}"
}
