variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Private subnet for the build host (uses NAT for Git/Maven)"
  type        = string
}

variable "maven_golden_ami_id" {
  type = string
}

variable "iam_instance_profile_name" {
  type = string
}

variable "bastion_subnet_cidr" {
  description = "Allow SSH from bastion subnet (hop via bastion + Transit Gateway)"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "git_repo_url" {
  description = "HTTPS URL of the Git repository to clone"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Secrets Manager API calls"
  type        = string
}

variable "app_secrets_manager_secret_id" {
  description = "Secrets Manager secret name or ARN; JSON keys jfrogusername and jfrogpassword for JFrog deploy"
  type        = string
}

variable "ec2_key_name" {
  description = "Optional EC2 key pair name for SSH as ec2-user from bastion"
  type        = string
  default     = ""
}
