output "db_endpoint" {
  description = "Endpoint PostgreSQL"
  value       = aws_db_instance.postgres.address
}
output "db_secret_arn" {
  description = "ARN du secret contenant le mot de passe PostgreSQL"
  value       = data.aws_secretsmanager_secret.db_password.arn
}
output "bastion_instance_id" {
  description = "ID de l'instance bastion pour tunnel SSM"
  value       = aws_instance.bastion.id
}

