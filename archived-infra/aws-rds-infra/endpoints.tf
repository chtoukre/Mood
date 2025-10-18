# -------------------------------
# Récupérer la région AWS
# -------------------------------
data "aws_region" "current" {}

# -------------------------------
# Security Group pour les VPC Endpoints
# -------------------------------
resource "aws_security_group" "vpce_sg" {
  name   = "vpc-endpoints-ssm-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from bastion"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpce-ssm-sg"
  }

}

# -------------------------------
# VPC Endpoint pour SSM
# -------------------------------
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

# -------------------------------
# VPC Endpoint pour SSM messages
# -------------------------------
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

# -------------------------------
# VPC Endpoint EC2 messages (SSM requiert)
# -------------------------------
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

# ✅ Endpoint S3 - nécessaire pour SSM en private mode
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = [
    aws_vpc.main.default_route_table_id
  ]
}

