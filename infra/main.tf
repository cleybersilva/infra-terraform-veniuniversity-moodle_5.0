# Terraform configuration for Moodle 5.0 on AWS
# main.tf

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

#########################################
# VPC and Networking
#########################################

# Create VPC
resource "aws_vpc" "moodle_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.moodle_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.moodle_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# Create database subnets
resource "aws_subnet" "database" {
  count             = length(var.database_subnet_cidrs)
  vpc_id            = aws_vpc.moodle_vpc.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-database-subnet-${count.index + 1}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "moodle_igw" {
  vpc_id = aws_vpc.moodle_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.moodle_igw]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "moodle_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.moodle_igw]
}

# Create public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.moodle_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.moodle_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Create private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.moodle_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.moodle_nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate public route table with public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private route table with private subnets
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Associate private route table with database subnets
resource "aws_route_table_association" "database" {
  count          = length(var.database_subnet_cidrs)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private.id
}

#########################################
# Security Groups
#########################################

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Moodle ALB"
  vpc_id      = aws_vpc.moodle_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Moodle EC2 Security Group
resource "aws_security_group" "moodle_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for Moodle EC2 instances"
  vpc_id      = aws_vpc.moodle_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for Moodle RDS"
  vpc_id      = aws_vpc.moodle_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.moodle_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ElastiCache Security Group
resource "aws_security_group" "elasticache_sg" {
  name        = "${var.project_name}-elasticache-sg"
  description = "Security group for Moodle ElastiCache"
  vpc_id      = aws_vpc.moodle_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.moodle_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-elasticache-sg"
  }
}

# EFS Security Group
resource "aws_security_group" "efs_sg" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for Moodle EFS"
  vpc_id      = aws_vpc.moodle_vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.moodle_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-efs-sg"
  }
}

#########################################
# RDS Database
#########################################

# Create DB subnet group
resource "aws_db_subnet_group" "moodle" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Create RDS instance
resource "aws_db_instance" "moodle" {
  identifier             = "${var.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.moodle.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = true
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot"
  backup_retention_period = 7
  backup_window          = "03:00-06:00"
  maintenance_window     = "Sun:00:00-Sun:03:00"
  apply_immediately      = true
  publicly_accessible    = false

  tags = {
    Name = "${var.project_name}-db"
  }
}

#########################################
# ElastiCache Redis
#########################################

# Create ElastiCache subnet group
resource "aws_elasticache_subnet_group" "moodle" {
  name       = "${var.project_name}-elasticache-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-elasticache-subnet-group"
  }
}

# Create ElastiCache Redis cluster
resource "aws_elasticache_cluster" "moodle" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = var.elasticache_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.moodle.name
  security_group_ids   = [aws_security_group.elasticache_sg.id]
  apply_immediately    = true

  tags = {
    Name = "${var.project_name}-redis"
  }
}

#########################################
# EFS for shared storage
#########################################

# Create EFS file system
resource "aws_efs_file_system" "moodle" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${var.project_name}-efs"
  }
}

# Create EFS mount targets in each private subnet
resource "aws_efs_mount_target" "moodle" {
  count           = length(var.private_subnet_cidrs)
  file_system_id  = aws_efs_file_system.moodle.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

#########################################
# S3 Bucket for backups and media
#########################################

# Create S3 bucket for backups
resource "aws_s3_bucket" "moodle_backups" {
  bucket = "${var.project_name}-backups-${var.environment}"

  tags = {
    Name = "${var.project_name}-backups"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "moodle_backups_versioning" {
  bucket = aws_s3_bucket.moodle_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "moodle_backups_encryption" {
  bucket = aws_s3_bucket.moodle_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "moodle_backups_lifecycle" {
  bucket = aws_s3_bucket.moodle_backups.id

  rule {
    id     = "backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

#########################################
# Application Load Balancer
#########################################

# Create ALB
resource "aws_lb" "moodle" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Create ALB target group
resource "aws_lb_target_group" "moodle" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.moodle_vpc.id
  
  health_check {
    path                = "/login/index.php"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# Create ALB listener
resource "aws_lb_listener" "moodle_http" {
  load_balancer_arn = aws_lb.moodle.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.moodle.arn
  }
}

# Optional HTTPS listener (uncomment and add your own certificate ARN)
/*
resource "aws_lb_listener" "moodle_https" {
  load_balancer_arn = aws_lb.moodle.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.moodle.arn
  }
}
*/

#########################################
# CloudFront Distribution
#########################################

resource "aws_cloudfront_distribution" "moodle" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for Moodle"
  default_root_object = "index.php"
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_lb.moodle.dns_name
    origin_id   = aws_lb.moodle.name
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.moodle.name

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["*"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use your own SSL certificate
  viewer_certificate {
    cloudfront_default_certificate = true
    # Comment out the above line and uncomment below when you have a certificate
    # acm_certificate_arn      = var.cloudfront_certificate_arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}

#########################################
# EC2 Launch Template and Auto Scaling Group
#########################################

# Create IAM role for EC2
resource "aws_iam_role" "moodle_ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "moodle_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.moodle_ec2_role.name
}

# Create IAM policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Policy for EC2 instances to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.moodle_backups.arn,
          "${aws_s3_bucket.moodle_backups.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.moodle_ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Attach SSM policy to role for easy management
resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.moodle_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create EC2 launch template
resource "aws_launch_template" "moodle" {
  name          = "${var.project_name}-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.moodle_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.moodle_sg.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    # Update system and install required packages
    yum update -y
    
    # Install AWS CloudWatch agent
    yum install -y amazon-cloudwatch-agent
    
    # Configure CloudWatch agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
    {
      "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/httpd/moodle_error.log",
                "log_group_name": "${aws_cloudwatch_log_group.moodle.name}",
                "log_stream_name": "{instance_id}/apache-error"
              },
              {
                "file_path": "/var/log/httpd/moodle_access.log",
                "log_group_name": "${aws_cloudwatch_log_group.moodle.name}",
                "log_stream_name": "{instance_id}/apache-access"
              },
              {
                "file_path": "/var/log/user-data.log",
                "log_group_name": "${aws_cloudwatch_log_group.moodle.name}",
                "log_stream_name": "{instance_id}/user-data"
              }
            ]
          }
        }
      },
      "metrics": {
        "metrics_collected": {
          "disk": {
            "measurement": ["used_percent"],
            "resources": ["*"]
          },
          "mem": {
            "measurement": ["mem_used_percent"]
          }
        }
      }
    }
    EOF
    
    # Start CloudWatch agent
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
    
    # Install Apache, PHP, and required extensions for Moodle 5.0
    dnf install -y httpd
    
    # For Amazon Linux 2023, we need to use dnf instead of amazon-linux-extras
    dnf install -y php php-cli php-fpm php-mysqlnd php-zip php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-intl php-soap php-opcache php-pecl-mcrypt php-pdo php-xmlrpc
    
    # Install EFS utilities and AWS CLI
    dnf install -y amazon-efs-utils awscli
    
    # Create mount directory and moodledata directory
    mkdir -p /var/www/moodle
    mkdir -p /var/www/moodledata
    
    # Mount EFS
    echo "${aws_efs_file_system.moodle.dns_name}:/ /var/www/moodle efs _netdev,tls,iam 0 0" >> /etc/fstab
    mount -a
    
    # Set correct permissions
    chown -R apache:apache /var/www/moodle
    chown -R apache:apache /var/www/moodledata
    chmod 755 /var/www/moodledata
    
    # Configure Apache
    cat > /etc/httpd/conf.d/moodle.conf << 'EOF'
    <VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/moodle
        
        <Directory /var/www/moodle>
            Options FollowSymlinks
            AllowOverride All
            Require all granted
        </Directory>
        
        <Directory /var/www/moodledata>
            Options FollowSymlinks
            AllowOverride All
            Require all granted
        </Directory>
        
        ErrorLog /var/log/httpd/moodle_error.log
        CustomLog /var/log/httpd/moodle_access.log combined
    </VirtualHost>
    EOF
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Download and extract Moodle 5.0
    if [ ! -f /var/www/moodle/index.php ]; then
        cd /tmp
        wget https://download.moodle.org/download.php/direct/stable400/moodle-latest-400.zip
        unzip moodle-latest-400.zip
        cp -R moodle/* /var/www/moodle/
        
        # Create moodle config file
        cat > /var/www/moodle/config.php << EOF
        <?php
        define('MOODLE_INTERNAL', true);
        
        \$CFG = new stdClass();
        \$CFG->dbtype    = 'mysqli';
        \$CFG->dblibrary = 'native';
        \$CFG->dbhost    = '${aws_db_instance.moodle.endpoint}';
        \$CFG->dbname    = '${var.db_name}';
        \$CFG->dbuser    = '${var.db_username}';
        \$CFG->dbpass    = '${var.db_password}';
        \$CFG->prefix    = 'mdl_';
        \$CFG->dboptions = array(
            'dbpersist' => false,
            'dbsocket'  => false,
            'dbport'    => '',
        );
        
        \$CFG->wwwroot   = 'https://${aws_cloudfront_distribution.moodle.domain_name}';
        \$CFG->dataroot  = '/var/www/moodledata';
        \$CFG->directorypermissions = 02777;
        \$CFG->admin = 'admin';
        
        // Use Redis for session handling
        \$CFG->session_handler_class = '\core\session\redis';
        \$CFG->session_redis_host = '${aws_elasticache_cluster.moodle.cache_nodes.0.address}';
        \$CFG->session_redis_port = 6379;
        \$CFG->session_redis_database = 0;
        \$CFG->session_redis_prefix = 'moodle_session_';
        
        // Use Redis for caching
        \$CFG->cache_store_backends[] = array(
            'name'          => 'Redis',
            'type'          => 'redis',
            'plugin'        => 'redis',
            'server'        => '${aws_elasticache_cluster.moodle.cache_nodes.0.address}',
            'prefix'        => 'moodle_cache_',
            'serializer'    => 1,
        );
        
        // Set default cache
        \$CFG->cache_stores = array(
            array(
                'name'          => 'Redis',
                'plugin'        => 'redis',
                'configuration' => array(
                    'server'        => '${aws_elasticache_cluster.moodle.cache_nodes.0.address}',
                    'prefix'        => 'moodle_cache_',
                    'password'      => '',
                    'serializer'    => 1,
                ),
            ),
        );
        \$CFG->cachejs = true;
        
        // Performance optimizations
        \$CFG->sslproxy = true;
        \$CFG->loglifetime = 60;
        \$CFG->pathtogs = '/usr/bin/gs';
        \$CFG->enablestats = false;
        \$CFG->enablenotes = false;
        \$CFG->enableblogs = false;
        \$CFG->cronclionly = true;
        \$CFG->cachetext = 0;
        
        require_once(__DIR__ . '/lib/setup.php');
        EOF
        
        # Set correct permissions
        chown -R apache:apache /var/www/moodle
        chown -R apache:apache /var/www/moodledata
        chmod -R 755 /var/www/moodle
        chmod -R 770 /var/www/moodledata
    fi
    
    # Install Redis client for PHP
    dnf install -y php-pecl-redis5
    
    # Configure PHP for better performance
    cat > /etc/php.d/moodle-performance.ini << 'EOF'
    memory_limit = 256M
    post_max_size = 512M
    upload_max_filesize = 512M
    max_execution_time = 300
    max_input_vars = 5000
    date.timezone = 'UTC'
    opcache.enable = 1
    opcache.memory_consumption = 128
    opcache.interned_strings_buffer = 8
    opcache.max_accelerated_files = 10000
    opcache.revalidate_freq = 60
    zlib.output_compression = On
    EOF
    
    # Restart Apache to apply changes
    systemctl restart httpd
    
    # Setup cron job for Moodle
    echo "*/15 * * * * apache /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null 2>&1" > /etc/cron.d/moodle
    
    # Setup daily backup to S3
    cat > /usr/local/bin/moodle-backup.sh << 'EOF'
    #!/bin/bash
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="/tmp/moodle-backup-$TIMESTAMP"
    
    # Create backup directory
    mkdir -p $BACKUP_DIR
    
    # Backup Moodle database
    mysqldump -h ${aws_db_instance.moodle.address} -u ${var.db_username} -p${var.db_password} ${var.db_name} > $BACKUP_DIR/moodle-db.sql
    
    # Compress backup
    tar -czf $BACKUP_DIR/moodle-backup-$TIMESTAMP.tar.gz -C $BACKUP_DIR moodle-db.sql
    
    # Upload to S3
    aws s3 cp $BACKUP_DIR/moodle-backup-$TIMESTAMP.tar.gz s3://${aws_s3_bucket.moodle_backups.bucket}/daily-backups/
    
    # Cleanup
    rm -rf $BACKUP_DIR
    EOF
    
    chmod +x /usr/local/bin/moodle-backup.sh
    echo "0 2 * * * root /usr/local/bin/moodle-backup.sh >/dev/null 2>&1" > /etc/cron.d/moodle-backup
    
    # Signal successful completion
    /opt/aws/bin/cfn-signal -e 0 --stack ${var.project_name} --resource MoodleAutoScalingGroup --region ${var.aws_region}
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "moodle" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  target_group_arns   = [aws_lb_target_group.moodle.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.moodle.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-instance"
    propagate_at_launch = true
  }
}

# Create Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.moodle.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.moodle.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

#########################################
# CloudWatch Alarms for Auto Scaling
#########################################

# Create CloudWatch Alarm for high CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.moodle.name
  }
}

# Create CloudWatch Alarm for low CPU
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.moodle.name
  }
}