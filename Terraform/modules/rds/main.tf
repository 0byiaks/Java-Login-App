# Get available AZs in the region
data "aws_availability_zones" "available_zones" {}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = lower("${var.environment}-${var.project_name}-db-subnet-group")
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "${var.environment}-${var.project_name}-db-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql_db" {
  identifier = lower("${var.environment}-${var.project_name}-mysql-db")

  # Engine Configuration
  engine         = "mysql"
  engine_version = var.mysql_engine_version
  instance_class = var.db_instance_class

  # Database Configuration
  db_name  = "UserDB"
  username = "admin"
  
  # AWS Managed Credentials (Secrets Manager)
  manage_master_user_password = true

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  # Availability Zone (Single AZ for staging/free tier - use AZ-1a)
  availability_zone = var.availability_zone != null ? var.availability_zone : data.aws_availability_zones.available_zones.names[0]

  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  # Deletion Protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = !var.deletion_protection

  # Monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name        = "${var.environment}-${var.project_name}-mysql-db"
    Environment = var.environment
    Project     = var.project_name
  }
}

