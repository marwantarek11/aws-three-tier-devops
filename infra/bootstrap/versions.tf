terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap creates the remote-state bucket, so it uses local state itself.
  # It is run once by an admin; its state file is git-ignored.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "shared"
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repository  = "${var.github_owner}/${var.github_repo}"
    }
  }
}
