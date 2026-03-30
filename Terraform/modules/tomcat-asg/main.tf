# Launch Template for Tomcat
resource "aws_launch_template" "tomcat_lt" {
  name_prefix   = "${var.environment}-${var.project_name}-tomcat-"
  image_id      = var.tomcat_golden_ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.tomcat_security_group_id]

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region                    = var.aws_region
    secret_id                     = var.app_secrets_manager_secret_id
    jfrog_war_url                 = var.jfrog_war_url
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-${var.project_name}-tomcat"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# Auto Scaling Group for Tomcat
resource "aws_autoscaling_group" "tomcat_asg" {
  name                = "${var.environment}-${var.project_name}-tomcat-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  desired_capacity     = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size

  launch_template {
    id      = aws_launch_template.tomcat_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-${var.project_name}-tomcat"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

