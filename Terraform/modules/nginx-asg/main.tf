resource "aws_launch_template" "nginx_lt" {
  name_prefix   = "${var.environment}-${var.project_name}-nginx-"
  image_id      = var.nginx_golden_ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.nginx_security_group_id]

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    private_nlb_dns_name = var.private_nlb_dns_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-${var.project_name}-nginx"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

resource "aws_autoscaling_group" "nginx_asg" {
  name                = "${var.environment}-${var.project_name}-nginx-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size

  launch_template {
    id      = aws_launch_template.nginx_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-${var.project_name}-nginx"
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
