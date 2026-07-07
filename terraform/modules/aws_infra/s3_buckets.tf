# General-purpose S3 bucket for the project (raw uploads, scripts, misc artifacts)
resource "aws_s3_bucket" "general_purpose" {
  bucket = "${var.project_name}-data-${var.environment}"

  tags = {
    Name        = "${var.project_name} General Purpose"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "general_purpose" {
  bucket = aws_s3_bucket.general_purpose.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "general_purpose" {
  bucket = aws_s3_bucket.general_purpose.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for cost optimisation
resource "aws_s3_bucket_lifecycle_configuration" "general_purpose" {
  bucket = aws_s3_bucket.general_purpose.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 730 # Delete after 2 years
    }
  }
}