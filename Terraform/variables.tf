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

variable "nginx_instance_type" {
  description = "Instance type for Nginx instances"
  type        = string
  default     = "t3.micro"
}

variable "tomcat_jfrog_war_url" {
  description = "HTTPS URL to the release WAR in JFrog (Maven path under libs-release-local)"
  type        = string
  default     = "https://trial8hq0mq.jfrog.io/artifactory/libs-release-local/com/devopsrealtime/dptweb/1.0/dptweb-1.0.war"
}

variable "maven_build_instance_type" {
  description = "Instance type for Maven build EC2 (needs enough RAM for mvn package)"
  type        = string
  default     = "t3.small"
}

variable "maven_build_git_repo_url" {
  description = "Public Git clone URL (default: 0byiaks/Java-Login-App)"
  type        = string
  default     = "https://github.com/0byiaks/Java-Login-App.git"
}

variable "maven_build_app_secret_name" {
  description = "Secrets Manager secret name (e.g. dev-app-secrets) with JSON keys jfrogusername and jfrogpassword for mvn deploy to JFrog"
  type        = string
  default     = "dev-app-secrets"
}

variable "maven_build_ec2_key_name" {
  description = "Optional EC2 key pair for SSH as ec2-user; leave empty to use SSM only"
  type        = string
  default     = ""
}
