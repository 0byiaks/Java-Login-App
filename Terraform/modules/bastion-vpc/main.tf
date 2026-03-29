# Bastion VPC
resource "aws_vpc" "bastion_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-vpc"
  }
}

# Internet Gateway for Bastion VPC
resource "aws_internet_gateway" "bastion_igw" {
  vpc_id = aws_vpc.bastion_vpc.id

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-igw"
  }
}

# Get available AZs in the region
data "aws_availability_zones" "available_zones" {}

# Public Subnet for Bastion Host
resource "aws_subnet" "bastion_public_subnet" {
  vpc_id                  = aws_vpc.bastion_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone        = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-public-subnet"
    Type = "public"
  }
}

# Route Table for Bastion Public Subnet
resource "aws_route_table" "bastion_public_rt" {
  vpc_id = aws_vpc.bastion_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bastion_igw.id
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-public-rtb"
  }
}

# Route Table Association for Bastion Public Subnet
resource "aws_route_table_association" "bastion_public_rt_association" {
  subnet_id      = aws_subnet.bastion_public_subnet.id
  route_table_id = aws_route_table.bastion_public_rt.id
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "${var.environment}-${var.project_name}-bastion-sg"
  description = "Security group for bastion host - Admin access only"
  vpc_id      = aws_vpc.bastion_vpc.id

  # Ingress: SSH from admin IP only
  ingress {
    description = "Allow SSH traffic from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip_cidr]
  }

  # Egress: Allow outbound to application VPC private resources
  egress {
    description = "Allow outbound to application VPC private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.app_vpc_private_cidrs
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-sg"
  }
}

