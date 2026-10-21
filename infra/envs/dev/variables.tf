variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Short project name used in resource names (lowercase, no spaces)."
  type        = string
  default     = "threetier"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,14}$", var.project))
    error_message = "project must be 3-15 chars: lowercase letters, digits, hyphens."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "repository" {
  description = "Source repository tag value (owner/name)."
  type        = string
}

variable "image_tag" {
  description = "API image tag to deploy (git SHA). Set by CI."
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR (/16)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs."
  type        = number
  default     = 2
}

variable "api_desired_count" {
  description = "Number of API tasks."
  type        = number
  default     = 1
}

variable "api_task_cpu" {
  description = "API task CPU units."
  type        = number
  default     = 256
}

variable "api_task_memory" {
  description = "API task memory (MiB)."
  type        = number
  default     = 512
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Enable RDS Multi-AZ."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection (and take a final snapshot on destroy)."
  type        = bool
  default     = false
}

variable "allow_destroy_with_data" {
  description = "Let terraform destroy the non-empty frontend bucket (demo convenience)."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 14
}
