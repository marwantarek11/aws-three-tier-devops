variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used for task egress to interface endpoints and RDS."
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB."
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "Private subnets for Fargate tasks."
  type        = list(string)
}

variable "s3_prefix_list_id" {
  description = "S3 gateway endpoint prefix list (ECR layer downloads)."
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the API image."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN, to scope the execution role's pull permissions."
  type        = string
}

variable "image_tag" {
  description = "Immutable image tag to deploy (git SHA)."
  type        = string

  validation {
    condition     = var.image_tag != "latest"
    error_message = "Deploy an immutable tag (git SHA), not \"latest\"."
  }
}

variable "container_port" {
  description = "Port the API listens on."
  type        = number
  default     = 8000
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running tasks."
  type        = number
  default     = 1
}

variable "db_host" {
  description = "Database hostname."
  type        = string
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN holding DB username/password (JSON keys: username, password)."
  type        = string
}

variable "origin_verify_header_name" {
  description = "Custom header CloudFront adds to origin requests."
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_verify_header_value" {
  description = "Shared secret value of the origin-verify header."
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "Retention for application logs."
  type        = number
  default     = 14
}

variable "permissions_boundary_arn" {
  description = "IAM permissions boundary attached to every role this module creates (required by the CI deploy role)."
  type        = string
  default     = null
}
