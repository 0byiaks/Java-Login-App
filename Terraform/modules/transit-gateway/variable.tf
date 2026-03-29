variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "app_vpc_id" {
  description = "Application VPC ID"
  type        = string
}

variable "app_vpc_subnet_ids" {
  description = "Application VPC subnet IDs for Transit Gateway attachment"
  type        = list(string)
}

variable "app_vpc_route_table_ids" {
  description = "Application VPC route table IDs"
  type        = list(string)
}

variable "app_vpc_cidr" {
  description = "Application VPC CIDR block"
  type        = string
}

variable "bastion_vpc_id" {
  description = "Bastion VPC ID"
  type        = string
}

variable "bastion_vpc_subnet_id" {
  description = "Bastion VPC subnet ID for Transit Gateway attachment"
  type        = string
}

variable "bastion_vpc_route_table_id" {
  description = "Bastion VPC route table ID"
  type        = string
}

variable "bastion_vpc_cidr" {
  description = "Bastion VPC CIDR block"
  type        = string
}

