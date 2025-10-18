terraform init
terraform apply -target=aws_s3_bucket.mood_backups \
  -target=aws_s3_bucket_public_access_block.mood_backups \
  -target=aws_s3_bucket_versioning.mood_backups \
  -target=aws_s3_bucket_server_side_encryption_configuration.mood_backups \
  -target=aws_s3_bucket_lifecycle_configuration.mood_backups

