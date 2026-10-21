variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the database in."
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnets (at least two AZs) for the DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS subnet groups need subnets in at least two AZs."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on 5432."
  type        = list(string)
}

variable "engine_major_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Instance class. db.t4g.micro is free-tier eligible."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "app"
}

variable "master_username" {
  description = "Master username (the password is generated and managed by RDS in Secrets Manager)."
  type        = string
  default     = "app_admin"
}

variable "allocated_storage_gb" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 50
}

variable "multi_az" {
  description = "Run a synchronous standby in a second AZ."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Block accidental deletion."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy (demo convenience; keep false in production)."
  type        = bool
  default     = true
}
