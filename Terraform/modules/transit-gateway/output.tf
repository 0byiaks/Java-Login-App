output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.tgw.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.tgw.arn
}

output "app_vpc_attachment_id" {
  description = "ID of the application VPC attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.app_vpc.id
}

output "bastion_vpc_attachment_id" {
  description = "ID of the bastion VPC attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.bastion_vpc.id
}

