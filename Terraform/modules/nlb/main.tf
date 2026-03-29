# Private Network Load Balancer for Tomcat
resource "aws_lb" "nlb" {
  name               = "${var.environment}-${var.project_name}-tomcat-nlb"
  internal           = true  # Private/internal NLB
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids  # Private subnets in AZ 1a and 1b

  enable_deletion_protection = false

  tags = {
    Name = "${var.environment}-${var.project_name}-tomcat-nlb"
  }
}

# Target Group for Tomcat
resource "aws_lb_target_group" "tomcat_tg" {
  name        = "${var.environment}-${var.project_name}-tomcat-tg"
  port        = 8080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "TCP"
    port                = 8080
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 10
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-tomcat-target-group"
  }
}

# Listener on Private NLB (Port 8080)
resource "aws_lb_listener" "tomcat_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat_tg.arn
  }
}
