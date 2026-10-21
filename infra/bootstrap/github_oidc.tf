# How GitHub Actions authenticates to AWS (var.ci_auth_mode):
#   "oidc"     - short-lived OIDC tokens, no AWS keys anywhere (preferred).
#   "iam_user" - for accounts whose guardrails deny iam:CreateOpenIDConnectProvider (e.g. AWS
#                sandbox projects). Two credential-only IAM users can do nothing except
#                sts:AssumeRole into the same least-privilege roles; their keys live only in
#                GitHub encrypted secrets (deploy keys in the main-only "dev" environment).

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  repo        = "${var.github_owner}/${var.github_repo}"
  name_prefix = "${var.project}-${var.environment}"
  oidc_host   = "token.actions.githubusercontent.com"
  use_oidc    = var.ci_auth_mode == "oidc"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = local.use_oidc ? 1 : 0

  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---- iam_user mode: credential-only users, one per role ----

resource "aws_iam_user" "ci" {
  for_each = local.use_oidc ? toset([]) : toset(["plan", "deploy"])

  name = "${var.project}-ci-${each.key}"
}

data "aws_iam_policy_document" "ci_user_assume" {
  for_each = aws_iam_user.ci

  statement {
    actions   = ["sts:AssumeRole", "sts:TagSession"]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project}-github-${each.key}"]
  }
}

resource "aws_iam_user_policy" "ci_user_assume" {
  for_each = aws_iam_user.ci

  name   = "assume-${each.key}-role-only"
  user   = each.value.name
  policy = data.aws_iam_policy_document.ci_user_assume[each.key].json
}

# =====================================================================
# Plan role: pull requests only, read-only
# =====================================================================

data "aws_iam_policy_document" "github_plan_trust" {
  dynamic "statement" {
    for_each = local.use_oidc ? [1] : []
    content {
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.github[0].arn]
      }

      condition {
        test     = "StringEquals"
        variable = "${local.oidc_host}:aud"
        values   = ["sts.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "${local.oidc_host}:sub"
        values   = ["repo:${local.repo}:pull_request"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.use_oidc ? [] : [1]
    content {
      actions = ["sts:AssumeRole", "sts:TagSession"]

      principals {
        type        = "AWS"
        identifiers = [aws_iam_user.ci["plan"].arn]
      }
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${var.project}-github-plan"
  description          = "terraform plan from pull requests in ${local.repo}"
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Only same-repo PRs can obtain this role (fork PRs get neither OIDC tokens nor secrets),
# and even then secret values stay unreadable.
data "aws_iam_policy_document" "github_plan_guardrails" {
  statement {
    sid       = "DenySecretReads"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue", "ssm:GetParameter*", "kms:Decrypt"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_plan_guardrails" {
  name   = "deny-secret-reads"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_guardrails.json
}

# =====================================================================
# Deploy role: only jobs running in the protected "dev" GitHub Environment
# (which itself only accepts deployments from main)
# =====================================================================

data "aws_iam_policy_document" "github_deploy_trust" {
  dynamic "statement" {
    for_each = local.use_oidc ? [1] : []
    content {
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.github[0].arn]
      }

      condition {
        test     = "StringEquals"
        variable = "${local.oidc_host}:aud"
        values   = ["sts.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "${local.oidc_host}:sub"
        values   = ["repo:${local.repo}:environment:${var.environment}"]
      }
    }
  }

  # Deploy keys are stored only as secrets of the main-only "dev" environment.
  dynamic "statement" {
    for_each = local.use_oidc ? [] : [1]
    content {
      actions = ["sts:AssumeRole", "sts:TagSession"]

      principals {
        type        = "AWS"
        identifiers = [aws_iam_user.ci["deploy"].arn]
      }
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.project}-github-deploy"
  description          = "Build/push image and terraform apply ${var.environment} from ${local.repo}"
  assume_role_policy   = data.aws_iam_policy_document.github_deploy_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_deploy" {
  # ---- Terraform remote state (this environment's key only) ----
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/envs/${var.environment}/*"]
  }

  # ---- Push images to this one repository ----
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListTagsForResource",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr_api.repository_arn]
  }

  # ---- Manage the services this stack uses, in the chosen region only ----
  statement {
    sid = "ManageRegionalServices"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "ecs:*",
      "rds:*",
      "logs:*",
      "cloudwatch:*",
      "sns:*",
      "kms:*",
      "secretsmanager:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # ---- Frontend bucket(s) of this project only ----
  statement {
    sid       = "ManageFrontendBuckets"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${local.name_prefix}-frontend-*"]
  }

  # ---- CloudFront is a global service (no region condition possible) ----
  statement {
    sid       = "ManageCloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }

  # ---- IAM: only roles named after this project/environment ----
  statement {
    sid = "ReadAndDeleteProjectRoles"
    actions = [
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name_prefix}-*"]
  }

  # Creating a role or changing its permissions is only allowed when the role carries the
  # workload boundary, which caps what any CI-created role can ever do.
  statement {
    sid = "WriteProjectRolesWithBoundaryOnly"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name_prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.workload_boundary.arn]
    }
  }

  statement {
    sid       = "ReadBoundaryPolicy"
    actions   = ["iam:GetPolicy", "iam:GetPolicyVersion"]
    resources = [aws_iam_policy.workload_boundary.arn]
  }

  statement {
    sid       = "PassProjectRolesToServices"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name_prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
  }

  # First use of ECS/ELB/RDS in a fresh account creates their service-linked roles.
  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "ecs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "rds.amazonaws.com",
      ]
    }
  }
  # Guardrails: CI never needs to read secret values or remove boundaries.
  statement {
    sid    = "DenySecretReadsAndBoundaryRemoval"
    effect = "Deny"
    actions = [
      "secretsmanager:GetSecretValue",
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = ["*"]
  }

  # Trust policies are static: CI must never re-point any role's trust (e.g. at its own OIDC
  # identity to assume a workload role) or touch the CI roles themselves.
  statement {
    sid       = "DenyTrustRewrites"
    effect    = "Deny"
    actions   = ["iam:UpdateAssumeRolePolicy"]
    resources = ["*"]
  }

  statement {
    sid    = "ProtectCiRoles"
    effect = "Deny"
    actions = [
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-github-*",
    ]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy-${var.environment}"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
