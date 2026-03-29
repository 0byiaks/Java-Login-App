
# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-${var.project_name}-igw"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
    subnet_id = aws_subnet.public_az1.id
    allocation_id = aws_eip.eip.id
}

# EIP for NAT Gateway
resource "aws_eip" "eip" {
    domain = "vpc"

    tags = {
        Name = "${var.environment}-${var.project_name}-nat-eip"
    }
    # Ensure the NAT Gateway is created after the Internet Gateway
    depends_on = [aws_internet_gateway.igw]
}


# Get avaiable AZs in the region
data "aws_availability_zones" "available_zones" {}

# Public Subnet 1
resource "aws_subnet" "public_az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_az1_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${var.project_name}-public-subnet-az1"
    Type        = "public"
  }
}

# Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_az2_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${var.project_name}-public-subnet-az2"
    Type        = "public"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
  tags = {
    Name = "${var.environment}-${var.project_name}-public-rtb"
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public_route_table_association_az1" {
  subnet_id = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_az2" {
  subnet_id = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Application Subnet 1
resource "aws_subnet" "private_app_az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_app_az1_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name        = "${var.environment}-${var.project_name}-private-subnet-app-az1"
    Type        = "private"
  }
}

# Private Application Subnet 2
resource "aws_subnet" "private_app_az2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_app_az2_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-${var.project_name}-private-subnet-app-az2"
    Type        = "private"
  }
}


# Route Table for Private Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-private-rtb"
  }
} 

# Route Table Association for Private Subnets
resource "aws_route_table_association" "private_route_table_association_app_az1" {
  subnet_id = aws_subnet.private_app_az1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_app_az2" {
  subnet_id = aws_subnet.private_app_az2.id
  route_table_id = aws_route_table.private_route_table.id
}


# Private Database Subnet 1
resource "aws_subnet" "private_db_az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_db_az1_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = false
}

# Private Database Subnet 2
resource "aws_subnet" "private_db_az2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_db_az2_cidr
  availability_zone = data.aws_availability_zones.available_zones.names[1]
  map_public_ip_on_launch = false
}

# Route Table Association for Private Database Subnets
resource "aws_route_table_association" "private_db_route_table_association_az1" {
  subnet_id = aws_subnet.private_db_az1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_db_route_table_association_az2" {
  subnet_id = aws_subnet.private_db_az2.id
  route_table_id = aws_route_table.private_route_table.id
}




# Security Group for nginx server (front tier)
resource "aws_security_group" "nginx_server_sg" {
  name = "${var.environment}-${var.project_name}-nginx-server-sg"
  description = "Security group for nginx server"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow HTTP traffic from the NLB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = var.nlb_security_group_id != "" ? [var.nlb_security_group_id] : []
    cidr_blocks = var.nlb_security_group_id == "" ? [var.vpc_cidr] : []
  }

  ingress {
    description = "Allow SSH traffic from bastion host"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks  = [var.bastion_subnet_cidr]
  }

  egress {
    description = "Allow outbound to private NLB/Tomcat (port 8080)"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Allow traffic to the private NLB
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-nginx-server-sg"
  }
}


# Security Group for tomcat server (back tier)
resource "aws_security_group" "tomcat_server_sg" {
  name = "${var.environment}-${var.project_name}-tomcat-server-sg"
  description = "Security group for tomcat server"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow Tomcat traffic from the nginx server"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [aws_security_group.nginx_server_sg.id]
  }

  ingress {
    description = "Allow SSH traffic from bastion host"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.bastion_subnet_cidr]
  }

  egress {
    description = "Allow outbound HTTPS for JFrog, Sonar, package repos"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound to database (port 3306)"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-tomcat-server-sg"
  }
}


# Security Group for Database (RDS)
resource "aws_security_group" "db_sg" {
  name = "${var.environment}-${var.project_name}-db-sg"
  description = "Security group for database (RDS)"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "Allow MySQL traffic from tomcat server"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.tomcat_server_sg.id]
  }

  ingress {
    description = "Allow MySQL traffic from bastion host (optional admin access)"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = [var.bastion_subnet_cidr]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Default is fine
}
