variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "nginx_golden_ami_id" {
  description = "ID of the Nginx golden AMI"
  type        = string
}

variable "nginx_security_group_id" {
  description = "Security group ID for Nginx instances"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for Nginx instances"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Nginx ASG"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the public NLB target group"
  type        = string
}

variable "private_nlb_dns_name" {
  description = "DNS name of the private Tomcat NLB"
  type        = string
}

variable "instance_type" {
  description = "Instance type for Nginx instances"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Desired number of Nginx instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of Nginx instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of Nginx instances"
  type        = number
  default     = 4
}
