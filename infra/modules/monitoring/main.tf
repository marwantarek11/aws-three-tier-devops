data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
  app_namespace = "${var.name_prefix}/app"
}

# =====================================================================
# Alert channel: encrypted SNS topic -> email
# =====================================================================

# The AWS-managed aws/sns key cannot be used by CloudWatch alarms, so a small CMK is needed.
data "aws_iam_policy_document" "sns_kms" {
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "sns" {
  description             = "${var.name_prefix} SNS alerts topic encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.sns_kms.json
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.name_prefix}-alerts"
  target_key_id = aws_kms_key.sns.key_id
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name_prefix}-alerts"
  kms_master_key_id = aws_kms_key.sns.arn
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =====================================================================
# Alarms
# =====================================================================

# Primary user-facing alarm: the API is returning server errors.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-api-5xx"
  alarm_description   = "API returned >= ${var.api_5xx_threshold} HTTP 5xx responses in 1 minute."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = var.api_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name_prefix}-api-unhealthy-targets"
  alarm_description   = "At least one API task is failing ALB health checks."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name_prefix}-api-cpu-high"
  alarm_description   = "API service average CPU above ${var.cpu_threshold_percent}% for 3 minutes."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.cpu_threshold_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name_prefix}-db-cpu-high"
  alarm_description   = "Database CPU above ${var.cpu_threshold_percent}% for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.db_instance_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.cpu_threshold_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.name_prefix}-db-storage-low"
  alarm_description   = "Database free storage below ${var.db_free_storage_threshold_gb} GiB."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_instance_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.db_free_storage_threshold_gb * 1024 * 1024 * 1024
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# Log-based alarm: turns ERROR lines in the API logs into a metric.
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.name_prefix}-api-error-lines"
  log_group_name = var.api_log_group_name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ApiErrorLogLines"
    namespace     = local.app_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_error_logs" {
  alarm_name          = "${var.name_prefix}-api-error-logs"
  alarm_description   = "API logged >= ${var.error_log_threshold} ERROR lines in 5 minutes."
  namespace           = local.app_namespace
  metric_name         = aws_cloudwatch_log_metric_filter.app_errors.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.error_log_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

# =====================================================================
# Dashboard
# =====================================================================

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB requests and errors"
          region = data.aws_region.current.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "ALB target response time (p95)"
          region  = data.aws_region.current.region
          stat    = "p95"
          period  = 60
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "ECS API CPU / memory (%)"
          region = data.aws_region.current.region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "RDS CPU (%) / connections"
          region = data.aws_region.current.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier],
            [".", "DatabaseConnections", ".", ".", { yAxis = "right" }],
          ]
        }
      },
      {
        type = "alarm", x = 0, y = 12, width = 24, height = 3
        properties = {
          title = "Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.alb_5xx.arn,
            aws_cloudwatch_metric_alarm.unhealthy_targets.arn,
            aws_cloudwatch_metric_alarm.ecs_cpu_high.arn,
            aws_cloudwatch_metric_alarm.rds_cpu_high.arn,
            aws_cloudwatch_metric_alarm.rds_storage_low.arn,
            aws_cloudwatch_metric_alarm.app_error_logs.arn,
          ]
        }
      },
      {
        type = "log", x = 0, y = 15, width = 24, height = 6
        properties = {
          title  = "Recent API errors"
          region = data.aws_region.current.region
          query  = "SOURCE '${var.api_log_group_name}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
    ]
  })
}
