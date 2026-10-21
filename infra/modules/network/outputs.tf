output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnets (ALB)."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private app subnets (ECS tasks, interface endpoints)."
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Private data subnets (RDS)."
  value       = aws_subnet.data[*].id
}

output "s3_prefix_list_id" {
  description = "Prefix list of the S3 gateway endpoint, for SG egress rules (ECR layer pulls)."
  value       = aws_vpc_endpoint.s3.prefix_list_id
}
