output "nginx_asg_id" {
  description = "ID of the Nginx Auto Scaling Group"
  value       = aws_autoscaling_group.nginx_asg.id
}

output "nginx_asg_name" {
  description = "Name of the Nginx Auto Scaling Group"
  value       = aws_autoscaling_group.nginx_asg.name
}

output "nginx_launch_template_id" {
  description = "ID of the Nginx launch template"
  value       = aws_launch_template.nginx_lt.id
}
