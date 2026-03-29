# Bastion VPC
output "bastion_vpc_id" {
  description = "ID of the Bastion VPC"
  value       = aws_vpc.bastion_vpc.id
}

# Bastion Public Subnet
output "bastion_public_subnet_id" {
  description = "ID of the bastion public subnet"
  value       = aws_subnet.bastion_public_subnet.id
}

# Bastion Internet Gateway
output "bastion_igw_id" {
  description = "ID of the bastion Internet Gateway"
  value       = aws_internet_gateway.bastion_igw.id
}

# Bastion Security Group
output "bastion_sg_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion_sg.id
}

# Route Table
output "bastion_public_route_table_id" {
  description = "ID of the bastion public route table"
  value       = aws_route_table.bastion_public_rt.id
}

