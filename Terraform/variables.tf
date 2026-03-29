variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "threat-composer"
}

variable "environment" {
  description = "Environment of the project"
  type        = string
  default     = "dev"
}

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
  description = "CIDR block for private app subnet in AZ1"
  type        = string
}

variable "private_subnet_app_az2_cidr" {
  description = "CIDR block for private app subnet in AZ2"
  type        = string
}

variable "private_subnet_db_az1_cidr" {
  description = "CIDR block for private db subnet in AZ1"
  type        = string
}

variable "private_subnet_db_az2_cidr" {
  description = "CIDR block for private db subnet in AZ2"
  type        = string
}

# Bastion VPC Variables
variable "bastion_vpc_cidr" {
  description = "CIDR block for Bastion VPC"
  type        = string
}

variable "bastion_public_subnet_cidr" {
  description = "CIDR block for bastion public subnet"
  type        = string
}

variable "admin_ip_cidr" {
  description = "CIDR block for admin IP address (e.g., '92.40.174.136/32')"
  type        = string
  default     = "92.40.174.136/32"
}








# AMI Builder Variables
variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH to AMI builder instance"
  type        = string
  default     = "92.40.174.136/32"
}

variable "ami_builder_instance_type" {
  description = "Instance type for AMI builder"
  type        = string
  default     = "t3.micro"
}

variable "tomcat_instance_type" {
  description = "Instance type for Tomcat instances"
  type        = string
  default     = "t3.micro"
}

variable "s3_bucket" {
  description = "S3 bucket name for WAR file (expects app.war in root)"
  type        = string
  default     = "project-artifacts-prod"
}
