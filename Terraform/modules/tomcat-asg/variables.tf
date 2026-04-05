variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "tomcat_golden_ami_id" {
  description = "ID of the Tomcat golden AMI"
  type        = string
}

variable "tomcat_security_group_id" {
  description = "Security group ID for Tomcat instances"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for Tomcat instances"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ASG (AZ 1a and 1b)"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the NLB target group"
  type        = string
}

variable "instance_type" {
  description = "Instance type for Tomcat instances"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

variable "aws_region" {
  description = "AWS region for Secrets Manager"
  type        = string
}

variable "app_secrets_manager_secret_id" {
  description = "Secrets Manager secret with jfrogusername and jfrogpassword"
  type        = string
}

variable "jfrog_war_url" {
  description = "Full HTTPS URL to the release WAR in Artifactory (Maven repo path)"
  type        = string
}

variable "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS master user (manage_master_user_password JSON with password key)"
  type        = string
}
