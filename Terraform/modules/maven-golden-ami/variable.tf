variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "global_base_ami_id" {
  description = "ID of the global base AMI to use as source"
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

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH to the instance"
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

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for the builder instance"
  type        = string
}

