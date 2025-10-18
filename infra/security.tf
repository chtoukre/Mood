# -----------------------------------------
# Security Group RDS PostgreSQL
# -----------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow PostgreSQL access from bastion only"
  vpc_id      = aws_vpc.main.id

  # Pas d'ingress ici -> ajouté plus tard depuis le bastion
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# -----------------------------------------
# Security Group Bastion privé
# -----------------------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-private-sg"
  description = "Private bastion for connecting via SSM"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }

}

# -----------------------------------------
# Autoriser Bastion -> PostgreSQL RDS
# -----------------------------------------
resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  description              = "Allow traffic from bastion to RDS PostgreSQL"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

