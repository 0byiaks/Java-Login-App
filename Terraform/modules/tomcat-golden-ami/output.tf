output "tomcat_golden_ami_id" {
  description = "ID of the created Tomcat golden AMI"
  value       = aws_ami_from_instance.tomcat_golden_ami.id
}

output "tomcat_golden_ami_name" {
  description = "Name of the created Tomcat golden AMI"
  value       = aws_ami_from_instance.tomcat_golden_ami.name
}

output "tomcat_golden_ami_arn" {
  description = "ARN of the created Tomcat golden AMI"
  value       = aws_ami_from_instance.tomcat_golden_ami.arn
}

