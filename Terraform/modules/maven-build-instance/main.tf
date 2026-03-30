resource "aws_security_group" "maven_build_sg" {
  name        = "${var.environment}-${var.project_name}-maven-build-sg"
  description = "Maven build instance: SSH from bastion, outbound for Git/Maven"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from bastion subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_subnet_cidr]
  }

  egress {
    description = "Outbound for Git, Maven, DNS (VPC resolver), and package repos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-maven-build-sg"
  }
}

resource "aws_instance" "maven_build" {
  ami                    = var.maven_golden_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.maven_build_sg.id]
  iam_instance_profile   = var.iam_instance_profile_name
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region   = var.aws_region
    secret_id    = var.app_secrets_manager_secret_id
    git_repo_url = var.git_repo_url
    # Interpolated here so the template is not parsed as bash $$ (PID) + APP_DIR — see user_data.sh
    app_dir = "/home/ec2-user/Java-Login-App/Java-Login-App"
  }))

  key_name = var.ec2_key_name != "" ? var.ec2_key_name : null

  tags = {
    Name        = "${var.environment}-${var.project_name}-maven-build-instance"
    Environment = var.environment
    Project     = var.project_name
  }
}
