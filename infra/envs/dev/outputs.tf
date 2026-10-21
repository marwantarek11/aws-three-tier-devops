output "app_url" {
  description = "Public HTTPS URL (CloudFront)."
  value       = module.frontend.url
}

output "frontend_bucket" {
  description = "Bucket the pipeline syncs the frontend into."
  value       = module.frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "Distribution the pipeline invalidates after a frontend deploy."
  value       = module.frontend.distribution_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "api_log_group" {
  description = "CloudWatch log group of the API."
  value       = module.ecs.log_group_name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.monitoring.dashboard_name
}

output "db_endpoint" {
  description = "Private RDS endpoint."
  value       = module.rds.address
}
