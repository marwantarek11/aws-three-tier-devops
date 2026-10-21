output "bucket_name" {
  description = "S3 bucket holding the static frontend."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the frontend bucket."
  value       = aws_s3_bucket.this.arn
}

output "distribution_id" {
  description = "CloudFront distribution ID (for cache invalidations)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "url" {
  description = "Public HTTPS URL of the application."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}
