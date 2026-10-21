# Shared secret CloudFront sends to the ALB so the ALB only serves CloudFront traffic.
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

# ECR lives in the bootstrap stack so images can be pushed before this stack exists.
data "aws_ecr_repository" "api" {
  name = "${local.name_prefix}-api"
}

# Created by infra/bootstrap; the CI deploy role may only create roles that carry it.
data "aws_iam_policy" "workload_boundary" {
  name = "${local.name_prefix}-workload-boundary"
}

module "network" {
  source = "../../modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  log_retention_days = var.log_retention_days

  permissions_boundary_arn = data.aws_iam_policy.workload_boundary.arn
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                = local.name_prefix
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.data_subnet_ids
  allowed_security_group_ids = [module.ecs.task_security_group_id]
  instance_class             = var.db_instance_class
  multi_az                   = var.db_multi_az
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = !var.db_deletion_protection
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix        = local.name_prefix
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  public_subnet_ids  = module.network.public_subnet_ids
  app_subnet_ids     = module.network.app_subnet_ids
  s3_prefix_list_id  = module.network.s3_prefix_list_id
  ecr_repository_url = data.aws_ecr_repository.api.repository_url
  ecr_repository_arn = data.aws_ecr_repository.api.arn
  image_tag          = var.image_tag
  desired_count      = var.api_desired_count
  task_cpu           = var.api_task_cpu
  task_memory        = var.api_task_memory
  log_retention_days = var.log_retention_days

  db_host       = module.rds.address
  db_name       = module.rds.db_name
  db_secret_arn = module.rds.master_user_secret_arn

  origin_verify_header_value = random_password.origin_verify.result
  permissions_boundary_arn   = data.aws_iam_policy.workload_boundary.arn
}

module "frontend" {
  source = "../../modules/frontend"

  name_prefix                = local.name_prefix
  alb_dns_name               = module.ecs.alb_dns_name
  origin_verify_header_value = random_password.origin_verify.result
  force_destroy              = var.allow_destroy_with_data
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix             = local.name_prefix
  alert_email             = var.alert_email
  alb_arn_suffix          = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  db_instance_identifier  = module.rds.identifier
  api_log_group_name      = module.ecs.log_group_name
}
