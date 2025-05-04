# variables.tf - Variáveis completas para a infraestrutura do Moodle

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "moodle"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "ssh_allowed_ips" {
  description = "List of IPs allowed to SSH to instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # For security, restrict to your IP in production
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "moodle"
}

variable "db_username" {
  description = "Username for database"
  type        = string
  default     = "moodleadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Password for database"
  type        = string
  sensitive   = true
}

variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.small"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Amazon Linux 2023
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of SSH key pair"
  type        = string
  default     = ""
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "certificate_arn" {
  description = "ARN of SSL certificate for ALB"
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ARN of SSL certificate for CloudFront"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address to receive alerts"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "enable_waf" {
  description = "Enable WAF protection"
  type        = bool
  default     = true
}

variable "enable_ssl" {
  description = "Enable SSL/TLS for ALB and CloudFront"
  type        = bool
  default     = false
}

variable "moodle_version" {
  description = "Version of Moodle to install"
  type        = string
  default     = "5.0"  # Atualizado para Moodle 5.0
}

variable "domain_name" {
  description = "Domain name for Moodle"
  type        = string
  default     = ""
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone for the domain"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

variable "maintenance_window" {
  description = "Maintenance window for RDS"
  type        = string
  default     = "Sun:00:00-Sun:03:00"
}

variable "backup_window" {
  description = "Backup window for RDS"
  type        = string
  default     = "03:00-06:00"
}

variable "cloudwatch_logs_retention" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "s3_lifecycle_rule_days" {
  description = "Number of days before moving objects to STANDARD_IA storage"
  type        = number
  default     = 30
}

variable "s3_lifecycle_glacier_days" {
  description = "Number of days before moving objects to GLACIER storage"
  type        = number
  default     = 90
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days before deleting objects"
  type        = number
  default     = 365
}