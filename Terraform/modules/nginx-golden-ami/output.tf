output "nginx_golden_ami_id" {
  description = "ID of the created Nginx golden AMI"
  value       = aws_ami_from_instance.nginx_golden_ami.id
}

output "nginx_golden_ami_name" {
  description = "Name of the created Nginx golden AMI"
  value       = aws_ami_from_instance.nginx_golden_ami.name
}

output "nginx_golden_ami_arn" {
  description = "ARN of the created Nginx golden AMI"
  value       = aws_ami_from_instance.nginx_golden_ami.arn
}

