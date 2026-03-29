variable "vpc_cidr" {
  description = "CIDR block for Bastion VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for bastion public subnet"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "admin_ip_cidr" {
  description = "CIDR block for admin IP (e.g., '92.40.174.136/32')"
  type        = string
}

variable "app_vpc_private_cidrs" {
  description = "List of CIDR blocks for application VPC private subnets"
  type        = list(string)
}


