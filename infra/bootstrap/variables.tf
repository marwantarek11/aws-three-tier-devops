variable "aws_region" {
  description = "Region for the state bucket, ECR and the regional resources CI may manage."
  type        = string
  default     = "eu-north-1"
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

variable "ci_auth_mode" {
  description = "How GitHub Actions authenticates: \"oidc\" (preferred, keyless) or \"iam_user\" (accounts that block OIDC providers)."
  type        = string
  default     = "oidc"

  validation {
    condition     = contains(["oidc", "iam_user"], var.ci_auth_mode)
    error_message = "ci_auth_mode must be \"oidc\" or \"iam_user\"."
  }
}
