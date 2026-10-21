data "aws_region" "current" {}

# AWS-maintained list of CloudFront origin-facing IPs: only CloudFront may reach the ALB.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  container_name = "api"
  image          = "${var.ecr_repository_url}:${var.image_tag}"
}

# =====================================================================
# Security groups: internet -> (CloudFront) -> ALB:80 -> task:8000 -> RDS:5432
# =====================================================================

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB: HTTP from CloudFront origin-facing IPs only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To API tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.task.id
}

resource "aws_security_group" "task" {
  name        = "${var.name_prefix}-api-task-sg"
  description = "API tasks: inbound from ALB only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-api-task-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "App port from ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "task_to_endpoints" {
  security_group_id = aws_security_group.task.id
  description       = "HTTPS to VPC interface endpoints (ECR, Logs, Secrets Manager)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "task_to_s3" {
  security_group_id = aws_security_group.task.id
  description       = "HTTPS to S3 gateway endpoint (ECR image layers)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = var.s3_prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "task_to_db" {
  security_group_id = aws_security_group.task.id
  description       = "PostgreSQL inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = var.vpc_cidr
}

# =====================================================================
# Application Load Balancer
# =====================================================================

resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "api" {
  name                 = "${var.name_prefix}-api-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 15

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Default: reject. Only requests carrying CloudFront's secret origin header are forwarded,
# so the ALB can't be hit directly or via someone else's CloudFront distribution.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    http_header {
      http_header_name = var.origin_verify_header_name
      values           = [var.origin_verify_header_value]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# =====================================================================
# Logging
# =====================================================================

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.name_prefix}/api"
  retention_in_days = var.log_retention_days
}

# =====================================================================
# IAM: execution role (ECS agent) vs task role (application code)
# =====================================================================

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-api-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# Scoped replacement for AmazonECSTaskExecutionRolePolicy (which allows every repo and log group):
# pull from one repository, write to one log group, read one secret.
data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level scoping
  }

  statement {
    sid = "EcrPullApiImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid       = "WriteApiLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.api.arn}:*"]
  }

  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "api-execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

# The app itself calls no AWS APIs, so its task role has no permissions at all.
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# =====================================================================
# Cluster, task definition, service
# =====================================================================

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name                   = local.container_name
    image                  = local.image
    essential              = true
    user                   = "10001:10001"
    readonlyRootFilesystem = true
    portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]

    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_SSLMODE", value = "require" },
      { name = "APP_VERSION", value = var.image_tag },
    ]

    # Injected at task start by the ECS agent from Secrets Manager; never in the image, repo or task definition.
    secrets = [
      { name = "DB_USER", valueFrom = "${var.db_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
    ]

    healthCheck = {
      command     = ["CMD", "python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:${var.container_port}/health', timeout=2).status == 200 else 1)"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds  = 30
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true

  # Failed deployments (tasks never become healthy) roll back to the previous task definition automatically.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.from_cloudfront]
}
