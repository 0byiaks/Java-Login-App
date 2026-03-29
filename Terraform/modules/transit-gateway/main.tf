# Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Transit Gateway for VPC connectivity"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  
  # Enable DNS support for cross-VPC communication
  dns_support = "enable"
  
  # Enable VPN ECMP (Equal-Cost Multi-Path routing)
  vpn_ecmp_support = "enable"

  tags = {
    Name = "${var.environment}-${var.project_name}-tgw"
  }
}

# Transit Gateway VPC Attachment for Application VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "app_vpc" {
  subnet_ids         = var.app_vpc_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = var.app_vpc_id

  tags = {
    Name = "${var.environment}-${var.project_name}-app-vpc-attachment"
  }
}

# Transit Gateway VPC Attachment for Bastion VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "bastion_vpc" {
  subnet_ids         = [var.bastion_vpc_subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = var.bastion_vpc_id

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-vpc-attachment"
  }
}

# Route in Application VPC route tables to Transit Gateway
resource "aws_route" "app_vpc_to_tgw" {
  count = length(var.app_vpc_route_table_ids)

  route_table_id         = var.app_vpc_route_table_ids[count.index]
  destination_cidr_block = var.bastion_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.app_vpc]
}

# Route in Bastion VPC route table to Transit Gateway
resource "aws_route" "bastion_vpc_to_tgw" {
  route_table_id         = var.bastion_vpc_route_table_id
  destination_cidr_block = var.app_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.bastion_vpc]
}

