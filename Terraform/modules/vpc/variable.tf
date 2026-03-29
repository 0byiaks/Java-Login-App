
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_az1_cidr" {
  description = "CIDR block for public subnet in AZ1"
  type        = string
}

variable "public_subnet_az2_cidr" {
  description = "CIDR block for public subnet in AZ2"
  type        = string
}

variable "private_subnet_app_az1_cidr" {
  description = "CIDR block for private subnet in AZ1 for application"
  type        = string
}

variable "private_subnet_app_az2_cidr" {
  description = "CIDR block for private subnet in AZ2 for application"
  type        = string
}

variable "private_subnet_db_az1_cidr" {
  description = "CIDR block for private subnet in AZ1 for database"
  type        = string
}

variable "private_subnet_db_az2_cidr" {
  description = "CIDR block for private subnet in AZ2 for database"
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

variable "bastion_subnet_cidr" {
  description = "CIDR block of the bastion subnet"
  type        = string
}

variable "nlb_security_group_id" {
  description = "Security group ID for the Network Load Balancer (optional, can be empty string if NLB not created yet)"
  type        = string
  default     = ""
}
