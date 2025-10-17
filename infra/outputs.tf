output "db_endpoint" {
  description = "Endpoint PostgreSQL"
  value       = aws_db_instance.postgres.address
}

