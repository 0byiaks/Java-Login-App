output "nlb_arn" {
  description = "ARN of the NLB"
  value       = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  description = "DNS name of the NLB"
  value       = aws_lb.nlb.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the NLB"
  value       = aws_lb.nlb.zone_id
}

output "tomcat_target_group_arn" {
  description = "ARN of the Tomcat target group"
  value       = aws_lb_target_group.tomcat_tg.arn
}

output "tomcat_target_group_id" {
  description = "ID of the Tomcat target group"
  value       = aws_lb_target_group.tomcat_tg.id
}
