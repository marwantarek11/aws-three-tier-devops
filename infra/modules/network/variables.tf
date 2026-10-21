variable "name_prefix" {
  description = "Prefix for resource names, e.g. \"threetier-dev\"."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a /16 (split into /20 subnets)."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid /16 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to span (ALB and RDS subnet groups need at least 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "log_retention_days" {
  description = "Retention for VPC flow logs."
  type        = number
  default     = 14
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary attached to every role this module creates (required by the CI deploy role)."
  type        = string
  default     = null
}
