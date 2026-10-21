variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "alert_email" {
  description = "Email subscribed to the alerts topic (must confirm the subscription). Empty = no subscription."
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address or empty."
  }
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (CloudWatch dimension)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix (CloudWatch dimension)."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name."
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "api_log_group_name" {
  description = "CloudWatch log group of the API containers."
  type        = string
}

variable "api_5xx_threshold" {
  description = "5xx responses per minute that trigger the alarm."
  type        = number
  default     = 5
}

variable "cpu_threshold_percent" {
  description = "CPU utilisation threshold for ECS and RDS alarms."
  type        = number
  default     = 80
}

variable "db_free_storage_threshold_gb" {
  description = "Free storage (GiB) below which the DB alarm fires."
  type        = number
  default     = 2
}

variable "error_log_threshold" {
  description = "ERROR log lines in 5 minutes that trigger the log-based alarm."
  type        = number
  default     = 10
}
