# outputs.tf

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.moodle_vpc.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "The IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.moodle.dns_name
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.moodle.domain_name
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.moodle.endpoint
}

output "rds_username" {
  description = "The master username of the RDS instance"
  value       = aws_db_instance.moodle.username
  sensitive   = true
}

output "elasticache_endpoint" {
  description = "The endpoint of the ElastiCache instance"
  value       = aws_elasticache_cluster.moodle.cache_nodes.0.address
}

output "efs_dns_name" {
  description = "The DNS name of the EFS file system"
  value       = aws_efs_file_system.moodle.dns_name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.moodle_backups.bucket
}

output "cloudwatch_log_group" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.moodle.name
}