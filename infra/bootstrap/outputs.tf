output "state_bucket" {
  description = "Remote state bucket name."
  value       = aws_s3_bucket.tfstate.id
}

output "backend_hcl" {
  description = "Contents for infra/envs/<env>/backend.hcl."
  value       = "bucket = \"${aws_s3_bucket.tfstate.id}\"\nregion = \"${var.aws_region}\"\n"
}

output "ecr_repository_url" {
  description = "ECR repository URL for the API image."
  value       = module.ecr_api.repository_url
}

output "plan_role_arn" {
  description = "Role GitHub Actions assumes for terraform plan on pull requests (read-only). Set as repo variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.github_plan.arn
}

output "deploy_role_arn" {
  description = "Role GitHub Actions assumes to deploy from the protected environment. Set as environment variable AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.github_deploy.arn
}
