# -------------------------------
# VPC
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# -------------------------------
# Subnet privé A
# -------------------------------
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-a"
  }
}

# -------------------------------
# Subnet privé B
# -------------------------------
resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-b"
  }
}

# -------------------------------
# DB Subnet Group pour RDS
# -------------------------------
resource "aws_db_subnet_group" "postgres_subnets" {
  name       = "postgres-subnet-group"
  subnet_ids = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id
  ]
  description = "Private subnets for PostgreSQL RDS"

  tags = {
    Name = "postgres-subnet-group"
  }
}

