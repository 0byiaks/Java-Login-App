output "public_nlb_arn" {
  description = "ARN of the public NLB"
  value       = aws_lb.public_nlb.arn
}

output "public_nlb_dns_name" {
  description = "DNS name of the public NLB"
  value       = aws_lb.public_nlb.dns_name
}

output "nginx_target_group_arn" {
  description = "ARN of the Nginx target group"
  value       = aws_lb_target_group.nginx_tg.arn
}

output "nginx_target_group_id" {
  description = "ID of the Nginx target group"
  value       = aws_lb_target_group.nginx_tg.id
}
