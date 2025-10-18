# -----------------------------------------
# Base de données PostgreSQL (RDS)
# -----------------------------------------
resource "aws_db_instance" "postgres" {
  identifier             = "my-postgres-db"
  engine                 = "postgres"
  engine_version         = "15" # dernière version stable série 15
  instance_class         = "db.t3.micro" # éligible au Free Tier AWS
  allocated_storage      = 20

  username               = var.db_username
  password = data.aws_secretsmanager_secret_version.db_password_value.secret_string


  db_subnet_group_name   = aws_db_subnet_group.postgres_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot    = true
  publicly_accessible    = false # ✅ privé comme on a choisi

  tags = {
    Name = "postgres-rds"
  }
}

