output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.mysql_db.id
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.mysql_db.endpoint
}

output "db_instance_address" {
  description = "RDS instance address"
  value       = aws_db_instance.mysql_db.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.mysql_db.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.mysql_db.db_name
}

output "master_user_secret_arn" {
  description = "ARN of the master user secret in AWS Secrets Manager"
  value       = aws_db_instance.mysql_db.master_user_secret[0].secret_arn
}

output "master_user_secret_kms_key_id" {
  description = "KMS key ID used to encrypt the master user secret"
  value       = aws_db_instance.mysql_db.master_user_secret[0].kms_key_id
}

