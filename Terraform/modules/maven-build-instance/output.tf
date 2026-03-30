output "instance_id" {
  description = "Maven build EC2 instance ID"
  value       = aws_instance.maven_build.id
}

output "private_ip" {
  description = "Private IP (SSH via bastion using this address)"
  value       = aws_instance.maven_build.private_ip
}

output "security_group_id" {
  value = aws_security_group.maven_build_sg.id
}
