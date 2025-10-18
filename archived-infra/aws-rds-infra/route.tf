# Route Table privée
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

# Associer subnet A
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

# Associer subnet B
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

