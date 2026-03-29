output "ami_id" {
  description = "ID of the created AMI"
  value       = aws_ami_from_instance.base_ami.id
}

output "ami_name" {
  description = "Name of the created AMI"
  value       = aws_ami_from_instance.base_ami.name
}

output "ami_arn" {
  description = "ARN of the created AMI"
  value       = aws_ami_from_instance.base_ami.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile for AMI builder"
  value       = aws_iam_instance_profile.ami_builder_profile.name
}

