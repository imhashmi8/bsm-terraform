output "db_endpoint" {
  description = "RDS endpoint hostname"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_sg_id" {
  description = "Security group ID for RDS instance"
  value       = aws_security_group.db.id
}

output "secret_arn" {
  description = "Secrets Manager ARN containing generated master user credentials"
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}
