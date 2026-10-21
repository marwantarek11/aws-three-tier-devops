locals {
  # Naming convention: <project>-<environment>-<component>, e.g. "threetier-dev-api-tg".
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Repository  = var.repository
  }
}
