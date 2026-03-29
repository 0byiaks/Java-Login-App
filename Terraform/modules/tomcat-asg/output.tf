output "tomcat_asg_id" {
  description = "ID of the Tomcat Auto Scaling Group"
  value       = aws_autoscaling_group.tomcat_asg.id
}

output "tomcat_asg_name" {
  description = "Name of the Tomcat Auto Scaling Group"
  value       = aws_autoscaling_group.tomcat_asg.name
}

output "tomcat_launch_template_id" {
  description = "ID of the Tomcat launch template"
  value       = aws_launch_template.tomcat_lt.id
}

