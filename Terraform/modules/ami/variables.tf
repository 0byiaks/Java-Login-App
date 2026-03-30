variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance will be created"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the temporary instance"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH to the instance (e.g., '92.40.174.136/32')"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "Instance type for the AMI builder"
  type        = string
  default     = "t3.micro"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "secretsmanager_secret_arns" {
  description = "ARNs of Secrets Manager secrets instances may read (e.g. Maven build app credentials)"
  type        = list(string)
  default     = []
}
