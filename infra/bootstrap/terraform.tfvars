aws_region   = "eu-north-1"
project      = "threetier"
environment  = "dev"
owner        = "marwan"
github_owner = "marwantarek11"
github_repo  = "aws-three-tier-devops"

# This AWS sandbox project's guardrails deny creating IAM OIDC providers.
ci_auth_mode = "iam_user"
