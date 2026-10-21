output "address" {
  description = "DNS address of the instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the database listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "identifier" {
  description = "RDS instance identifier (CloudWatch dimension)."
  value       = aws_db_instance.this.identifier
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret holding username/password."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group attached to the database."
  value       = aws_security_group.db.id
}
