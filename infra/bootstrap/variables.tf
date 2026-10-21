variable "aws_region" {
  description = "Region for the state bucket, ECR and the regional resources CI may manage."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name; must match the env stacks (used in names and IAM scoping)."
  type        = string
  default     = "threetier"
}

variable "environment" {
  description = "Environment the ECR repo and deploy role serve."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "github_owner" {
  description = "GitHub user/org that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}
