# Permissions boundary for every IAM role the CI pipeline creates (ECS task roles, flow-log role).
# CI may only create/modify roles that carry this boundary, so even a malicious change to the
# Terraform code cannot mint a role more powerful than this (no privilege escalation via CI).
data "aws_iam_policy_document" "workload_boundary" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [module.ecr_api.repository_arn]
  }

  statement {
    sid = "WriteProjectLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${local.name_prefix}/*",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/vpc/${local.name_prefix}/*",
    ]
  }

  # RDS-managed master secrets are named "rds!..." and tagged by RDS with their owning instance;
  # the tag condition limits this to this environment's databases only.
  statement {
    sid       = "ReadOwnRdsManagedSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:rds!*"]

    condition {
      test     = "StringLike"
      variable = "secretsmanager:ResourceTag/aws:rds:primaryDBInstanceArn"
      values   = ["arn:aws:rds:${var.aws_region}:${local.account_id}:db:${local.name_prefix}-*"]
    }
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "${local.name_prefix}-workload-boundary"
  description = "Maximum permissions for IAM roles created by the ${local.name_prefix} pipeline"
  policy      = data.aws_iam_policy_document.workload_boundary.json
}
