variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for bastion host"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for bastion host"
  type        = string
}

variable "instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "use_global_base_ami" {
  description = "Use global base AMI instead of Amazon Linux 2"
  type        = bool
  default     = false
}

variable "global_base_ami_id" {
  description = "Global base AMI ID (required if use_global_base_ami is true)"
  type        = string
  default     = ""
}

variable "rds_endpoint" {
  description = "RDS instance endpoint"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN of the RDS master user secret in Secrets Manager"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "s3_bucket_uri" {
  description = "S3 URI for the database schema SQL file"
  type        = string
  default     = "s3://dev-shop-app-webfiles/schema.sql"
}

variable "rds_dependency" {
  description = "RDS instance dependency to ensure secrets are created first"
  type        = any
  default     = null
}

