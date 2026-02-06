# BetterBooks Storage Module
# Creates S3 buckets for audiobooks and static assets

# Random suffix for globally unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for Audiobooks
resource "aws_s3_bucket" "audiobooks" {
  bucket = "${var.project_name}-${var.environment}-audiobooks-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-${var.environment}-audiobooks"
  }
}

# Block public access for audiobooks bucket
resource "aws_s3_bucket_public_access_block" "audiobooks" {
  bucket = aws_s3_bucket.audiobooks.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning for audiobooks (optional, costs extra for storage)
resource "aws_s3_bucket_versioning" "audiobooks" {
  bucket = aws_s3_bucket.audiobooks.id

  versioning_configuration {
    status = "Disabled"  # Enable for production if needed
  }
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "audiobooks" {
  bucket = aws_s3_bucket.audiobooks.id

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CORS configuration for audiobooks
resource "aws_s3_bucket_cors_configuration" "audiobooks" {
  bucket = aws_s3_bucket.audiobooks.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]  # Restrict in production
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# S3 Bucket for Static Web Assets
resource "aws_s3_bucket" "static" {
  bucket = "${var.project_name}-${var.environment}-static-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-${var.environment}-static"
  }
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"  # SPA fallback
  }
}

# Public access for static website
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy for public read access
resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.static]
}
