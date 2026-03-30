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

# IAM Role for EC2 Instance
resource "aws_iam_role" "ami_builder_role" {
  name = "${var.environment}-${var.project_name}-ami-builder-role"

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
    Name = "${var.environment}-${var.project_name}-ami-builder-role"
  }
}

locals {
  ami_builder_secrets_statement = length(var.secretsmanager_secret_arns) > 0 ? [
    {
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = var.secretsmanager_secret_arns
    }
  ] : []
}

# IAM Policy for SSM, CloudWatch, EC2, S3, and optional Secrets Manager
resource "aws_iam_role_policy" "ami_builder_policy" {
  name = "${var.environment}-${var.project_name}-ami-builder-policy"
  role = aws_iam_role.ami_builder_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
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
            "cloudwatch:PutMetricData",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeVolumes",
            "ec2:DescribeTags"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject"
          ]
          Resource = "arn:aws:s3:::project-artifacts-prod/*"
        }
      ],
      local.ami_builder_secrets_statement
    )
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ami_builder_profile" {
  name = "${var.environment}-${var.project_name}-ami-builder-profile"
  role = aws_iam_role.ami_builder_role.name

  tags = {
    Name = "${var.environment}-${var.project_name}-ami-builder-profile"
  }
}

# Security Group for AMI Builder Instance
resource "aws_security_group" "ami_builder_sg" {
  name        = "${var.environment}-${var.project_name}-ami-builder-sg"
  description = "Security group for AMI builder instance - SSH only from specified IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH from specified IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-ami-builder-sg"
  }
}

# User Data Script for Instance Configuration
locals {
  user_data = file("${path.module}/user_data.sh")
}

# Temporary EC2 Instance for AMI Creation
resource "aws_instance" "ami_builder" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.ami_builder_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ami_builder_profile.name
  user_data              = base64encode(local.user_data)
  associate_public_ip_address = true

  tags = {
    Name = "${var.environment}-${var.project_name}-ami-builder-temp"
  }

  # Wait for instance to be ready before creating AMI
  lifecycle {
    create_before_destroy = true
  }
}

# Wait for instance to be ready (user_data script completion)
resource "time_sleep" "wait_for_configuration" {
  depends_on = [aws_instance.ami_builder]

  create_duration = "5m"
}

# Stop the instance before creating AMI
resource "null_resource" "stop_instance" {
  depends_on = [time_sleep.wait_for_configuration]

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 stop-instances --instance-ids ${aws_instance.ami_builder.id} --region ${var.aws_region}
      aws ec2 wait instance-stopped --instance-ids ${aws_instance.ami_builder.id} --region ${var.aws_region}
    EOT
  }
}

# Create AMI from stopped instance
resource "aws_ami_from_instance" "base_ami" {
  depends_on = [null_resource.stop_instance]

  name                = "${var.environment}-${var.project_name}-global-base-ami-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  description         = "Global Base AMI with Amazon Linux 2, CloudWatch Agent, and SSM Agent configured. Created on ${timestamp()}"
  source_instance_id  = aws_instance.ami_builder.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-global-base-ami"
    Version     = formatdate("YYYYMMDDhhmmss", timestamp())
    Environment = var.environment
    Project     = var.project_name
  }
}

# Terminate the temporary instance after AMI creation
resource "null_resource" "terminate_instance" {
  depends_on = [aws_ami_from_instance.base_ami]

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 terminate-instances --instance-ids ${aws_instance.ami_builder.id} --region ${var.aws_region}
    EOT
  }
}

