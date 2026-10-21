output "sns_topic_arn" {
  description = "ARN of the alerts SNS topic."
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "alarm_names" {
  description = "Names of all alarms created."
  value = [
    aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_targets.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_cpu_high.alarm_name,
    aws_cloudwatch_metric_alarm.rds_cpu_high.alarm_name,
    aws_cloudwatch_metric_alarm.rds_storage_low.alarm_name,
    aws_cloudwatch_metric_alarm.app_error_logs.alarm_name,
  ]
}
