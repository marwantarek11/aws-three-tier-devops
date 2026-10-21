output "alb_dns_name" {
  description = "DNS name of the ALB (CloudFront origin)."
  value       = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix (CloudWatch dimension)."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix (CloudWatch dimension)."
  value       = aws_lb_target_group.api.arn_suffix
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.api.name
}

output "task_security_group_id" {
  description = "Security group of the API tasks (allowed into RDS)."
  value       = aws_security_group.task.id
}

output "log_group_name" {
  description = "CloudWatch log group of the API."
  value       = aws_cloudwatch_log_group.api.name
}

output "execution_role_arn" {
  description = "Task execution role ARN."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "Task role ARN."
  value       = aws_iam_role.task.arn
}
