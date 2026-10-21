provider "aws" {
  region = var.aws_region

  # Tagging convention: every taggable resource gets these automatically.
  default_tags {
    tags = local.common_tags
  }
}
