
output "base_ami_id" {
  description = "ID of the created global base AMI"
  value       = module.ami.ami_id
}

output "base_ami_name" {
  description = "Name of the created global base AMI"
  value       = module.ami.ami_name
}

# Nginx Golden AMI Outputs
output "nginx_golden_ami_id" {
  description = "ID of the created Nginx golden AMI"
  value       = module.nginx_golden_ami.nginx_golden_ami_id
}

output "nginx_golden_ami_name" {
  description = "Name of the created Nginx golden AMI"
  value       = module.nginx_golden_ami.nginx_golden_ami_name
}

# Tomcat Golden AMI Outputs
output "tomcat_golden_ami_id" {
  description = "ID of the created Tomcat golden AMI"
  value       = module.tomcat_golden_ami.tomcat_golden_ami_id
}

output "tomcat_golden_ami_name" {
  description = "Name of the created Tomcat golden AMI"
  value       = module.tomcat_golden_ami.tomcat_golden_ami_name
}

# Maven Golden AMI Outputs
output "maven_golden_ami_id" {
  description = "ID of the created Maven golden AMI"
  value       = module.maven_golden_ami.maven_golden_ami_id
}

output "maven_golden_ami_name" {
  description = "Name of the created Maven golden AMI"
  value       = module.maven_golden_ami.maven_golden_ami_name
}

# Transit Gateway Outputs
output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "bastion_sg_id" {
  description = "ID of the bastion security group"
  value       = module.bastion_vpc.bastion_sg_id
}

output "bastion_vpc_id" {
  description = "ID of the bastion VPC"
  value       = module.bastion_vpc.bastion_vpc_id
}

# RDS Database Outputs
output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}

output "rds_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_instance_address" {
  description = "RDS instance address"
  value       = module.rds.db_instance_address
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

output "rds_db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "rds_master_user_secret_arn" {
  description = "ARN of the master user secret in AWS Secrets Manager"
  value       = module.rds.master_user_secret_arn
  sensitive   = true
}

# Bastion Host Outputs
output "bastion_instance_id" {
  description = "ID of the bastion EC2 instance"
  value       = module.bastion_host.bastion_instance_id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = module.bastion_host.bastion_public_ip
}

output "bastion_public_dns" {
  description = "Public DNS name of the bastion host"
  value       = module.bastion_host.bastion_public_dns
}

# NLB Outputs
output "nlb_dns_name" {
  description = "DNS name of the private NLB for Tomcat"
  value       = module.nlb.nlb_dns_name
}

output "nlb_arn" {
  description = "ARN of the private NLB"
  value       = module.nlb.nlb_arn
}

output "tomcat_target_group_arn" {
  description = "ARN of the Tomcat target group"
  value       = module.nlb.tomcat_target_group_arn
}

output "tomcat_target_group_id" {
  description = "ID of the Tomcat target group"
  value       = module.nlb.tomcat_target_group_id
}

# Tomcat ASG Outputs
output "tomcat_asg_id" {
  description = "ID of the Tomcat Auto Scaling Group"
  value       = module.tomcat_asg.tomcat_asg_id
}

output "tomcat_asg_name" {
  description = "Name of the Tomcat Auto Scaling Group"
  value       = module.tomcat_asg.tomcat_asg_name
}