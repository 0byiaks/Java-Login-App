# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# IAM Role for Bastion Host
resource "aws_iam_role" "bastion_role" {
  name = "${var.environment}-${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-role"
  }
}

# IAM Policy for SSM, Secrets Manager, and S3
resource "aws_iam_role_policy" "bastion_policy" {
  name = "${var.environment}-${var.project_name}-bastion-policy"
  role = aws_iam_role.bastion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::dev-shop-app-webfiles/*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.environment}-${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion_role.name

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-profile"
  }
}

# User Data Script - Read from separate file and inject variables
locals {
  user_data = templatefile("${path.module}/user_data.sh", {
    rds_secret_arn = var.rds_secret_arn
    aws_region     = var.aws_region
    rds_endpoint   = var.rds_endpoint
    s3_bucket_uri  = var.s3_bucket_uri
  })
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = var.use_global_base_ami ? var.global_base_ami_id : data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  user_data              = base64encode(local.user_data)
  associate_public_ip_address = true

  # Ensure RDS and its secret are created before bastion host
  depends_on = [var.rds_dependency]

  tags = {
    Name = "${var.environment}-${var.project_name}-bastion-host"
  }
}

