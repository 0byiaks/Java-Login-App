output "maven_golden_ami_id" {
  description = "ID of the created Maven golden AMI"
  value       = aws_ami_from_instance.maven_golden_ami.id
}

output "maven_golden_ami_name" {
  description = "Name of the created Maven golden AMI"
  value       = aws_ami_from_instance.maven_golden_ami.name
}

output "maven_golden_ami_arn" {
  description = "ARN of the created Maven golden AMI"
  value       = aws_ami_from_instance.maven_golden_ami.arn
}

