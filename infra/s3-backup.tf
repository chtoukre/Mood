# === S3 bucket for PostgreSQL backups ===
resource "aws_s3_bucket" "mood_backups" {
  bucket = "mood-tracker-backups" # doit être globalement unique; si déjà pris, ajoute un suffixe
}

# Bloque tout accès public
resource "aws_s3_bucket_public_access_block" "mood_backups" {
  bucket                  = aws_s3_bucket.mood_backups.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Versioning (optionnel mais recommandé pour retrouver des anciennes sauvegardes)
resource "aws_s3_bucket_versioning" "mood_backups" {
  bucket = aws_s3_bucket.mood_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption par défaut (SSE-S3 / AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "mood_backups" {
  bucket = aws_s3_bucket.mood_backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle (optionnel): supprime les dumps > 180 jours
resource "aws_s3_bucket_lifecycle_configuration" "mood_backups" {
  bucket = aws_s3_bucket.mood_backups.id
  rule {
    id     = "expire-old-dumps"
    status = "Enabled"

    filter {
      prefix = "postgres/"
    }

    expiration {
      days = 180
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

output "backup_bucket" {
  value       = aws_s3_bucket.mood_backups.bucket
  description = "S3 bucket for DB backups"
}

