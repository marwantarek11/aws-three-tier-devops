terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Partial config: bucket/region come from backend.hcl (output of infra/bootstrap).
  # S3-native locking (use_lockfile) replaces the old DynamoDB lock table.
  backend "s3" {
    key          = "envs/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
