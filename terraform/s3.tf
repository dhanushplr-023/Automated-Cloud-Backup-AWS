# Generate a random 6-character suffix to guarantee global uniqueness of the bucket name
resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

# The Amazon S3 Backup Bucket
resource "aws_s3_bucket" "backup_bucket" {
  bucket        = "${var.project_name}-vault-${random_string.bucket_suffix.result}"
  force_destroy = true # Allows easy clean up during tear down

  tags = {
    Name        = "${var.project_name}-vault"
    Purpose     = "Automated EC2 Backup Vault"
  }
}

# Enforce Block Public Access (Zero-Trust Security)
resource "aws_s3_bucket_public_access_block" "backup_bucket_access" {
  bucket = aws_s3_bucket.backup_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce Server-Side Encryption (AES-256 / SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "backup_bucket_encryption" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle Configuration: Expire backups after 14 days for Free Tier protection
resource "aws_s3_bucket_lifecycle_configuration" "backup_bucket_lifecycle" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }
  }
}
