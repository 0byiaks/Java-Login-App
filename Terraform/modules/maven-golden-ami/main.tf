# Security Group for Maven Golden AMI Builder Instance
resource "aws_security_group" "maven_golden_ami_builder_sg" {
  name        = "${var.environment}-${var.project_name}-maven-golden-ami-builder-sg"
  description = "Security group for Maven golden AMI builder instance"
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
    Name = "${var.environment}-${var.project_name}-maven-golden-ami-builder-sg"
  }
}

# User Data Script for Maven Configuration
locals {
  user_data = file("${path.module}/user_data.sh")
}

# Temporary EC2 Instance for Maven Golden AMI Creation
resource "aws_instance" "maven_golden_ami_builder" {
  ami                    = var.global_base_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.maven_golden_ami_builder_sg.id]
  iam_instance_profile   = var.iam_instance_profile_name
  user_data              = base64encode(local.user_data)
  associate_public_ip_address = true

  tags = {
    Name = "${var.environment}-${var.project_name}-maven-golden-ami-builder-temp"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Wait for instance configuration to complete
resource "time_sleep" "wait_for_maven_configuration" {
  depends_on = [aws_instance.maven_golden_ami_builder]

  create_duration = "3m"
}

# Restart instance to validate Maven configuration persists on boot
resource "null_resource" "restart_instance" {
  depends_on = [time_sleep.wait_for_maven_configuration]

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 reboot-instances --instance-ids ${aws_instance.maven_golden_ami_builder.id} --region ${var.aws_region}
      aws ec2 wait instance-status-ok --instance-ids ${aws_instance.maven_golden_ami_builder.id} --region ${var.aws_region}
    EOT
  }
}

# Wait after restart for services to start
resource "time_sleep" "wait_after_restart" {
  depends_on = [null_resource.restart_instance]

  create_duration = "2m"
}

# Stop the instance before creating AMI
resource "null_resource" "stop_instance" {
  depends_on = [time_sleep.wait_after_restart]

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 stop-instances --instance-ids ${aws_instance.maven_golden_ami_builder.id} --region ${var.aws_region}
      aws ec2 wait instance-stopped --instance-ids ${aws_instance.maven_golden_ami_builder.id} --region ${var.aws_region}
    EOT
  }
}

# Create Maven Golden AMI from stopped instance
resource "aws_ami_from_instance" "maven_golden_ami" {
  depends_on = [null_resource.stop_instance]

  name                = "${var.environment}-${var.project_name}-maven-golden-ami-${formatdate("YYYYMMDD", timestamp())}"
  description         = "Maven Golden AMI with JDK 11, Git, and Apache Maven installed and configured. Created on ${timestamp()}"
  source_instance_id  = aws_instance.maven_golden_ami_builder.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-maven-golden-ami"
    Role        = "maven"
    Version     = formatdate("YYYYMMDD", timestamp())
    Environment = var.environment
    Project     = var.project_name
  }
}

# Terminate the temporary instance after AMI creation
resource "null_resource" "terminate_instance" {
  depends_on = [aws_ami_from_instance.maven_golden_ami]

  triggers = {
    ami_id      = aws_ami_from_instance.maven_golden_ami.id
    instance_id = aws_instance.maven_golden_ami_builder.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 terminate-instances --instance-ids ${aws_instance.maven_golden_ami_builder.id} --region ${var.aws_region} || true
    EOT
  }
}

