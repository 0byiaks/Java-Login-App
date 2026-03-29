# VPC
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.vpc.id
}

# Public Subnets
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public_az1.id, aws_subnet.public_2.id]
}

# Private App Subnets
output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = [aws_subnet.private_app_az1.id, aws_subnet.private_app_az2.id]
}

# Private DB Subnets
output "private_db_subnet_ids" {
  description = "IDs of the private database subnets"
  value       = [aws_subnet.private_db_az1.id, aws_subnet.private_db_az2.id]
}

# Security Groups
output "tomcat_security_group_id" {
  description = "ID of the Tomcat security group"
  value       = aws_security_group.tomcat_server_sg.id
}

output "nginx_security_group_id" {
  description = "ID of the Nginx security group"
  value       = aws_security_group.nginx_server_sg.id
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db_sg.id
}


# NAT Gateway
output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.nat_gateway.id
}

# Route Tables
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_route_table.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private_route_table.id
}

