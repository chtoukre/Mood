# -----------------------------------------
# AMI Amazon Linux 2
# -----------------------------------------
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -----------------------------------------
# IAM Role pour autoriser SSM
# -----------------------------------------
resource "aws_iam_role" "bastion_role" {
  name = "bastion-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-ssm-instance-profile"
  role = aws_iam_role.bastion_role.name
}

# -----------------------------------------
# Instance Bastion privée (sans IP publique)
# -----------------------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_a.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y postgresql
              EOF

  tags = {
    Name = "bastion-private"
  }
}

