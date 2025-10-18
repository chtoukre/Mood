data "aws_secretsmanager_secret" "db_password" {
  name = "rds-postgres-password"
}

data "aws_secretsmanager_secret_version" "db_password_value" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

