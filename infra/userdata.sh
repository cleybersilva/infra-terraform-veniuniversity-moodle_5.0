#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Moodle 5.0 initialization script..."

# Update system and install required packages
dnf update -y
dnf install -y amazon-cloudwatch-agent

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
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/apache-error"
          },
          {
            "file_path": "/var/log/httpd/moodle_access.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/apache-access"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/user-data"
          },
          {
            "file_path": "/var/www/moodledata/moodle.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/moodle-application"
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

echo "Installing Apache, PHP, and required extensions..."
# Install Apache, PHP, and required extensions for Moodle 5.0
dnf install -y httpd
dnf install -y php php-cli php-fpm php-mysqlnd php-zip php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-intl php-soap php-opcache php-pecl-mcrypt php-pdo php-xmlrpc

# Install EFS utilities and AWS CLI
echo "Installing EFS utilities and AWS CLI..."
dnf install -y amazon-efs-utils awscli

# Create mount directory and moodledata directory
echo "Creating mount directories..."
mkdir -p /var/www/moodle
mkdir -p /var/www/moodledata

# Mount EFS
echo "Mounting EFS..."
echo "${efs_dns_name}:/ /var/www/moodle efs _netdev,tls,iam 0 0" >> /etc/fstab
mount -a

# Set correct permissions
chown -R apache:apache /var/www/moodle
chown -R apache:apache /var/www/moodledata
chmod 755 /var/www/moodledata

# Configure Apache
echo "Configuring Apache..."
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

echo "Downloading and configuring Moodle 5.0..."
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
    \$CFG->dbhost    = '${db_endpoint}';
    \$CFG->dbname    = '${db_name}';
    \$CFG->dbuser    = '${db_username}';
    \$CFG->dbpass    = '${db_password}';
    \$CFG->prefix    = 'mdl_';
    \$CFG->dboptions = array(
        'dbpersist' => false,
        'dbsocket'  => false,
        'dbport'    => '',
    );
    
    \$CFG->wwwroot   = 'https://${cloudfront_domain}';
    \$CFG->dataroot  = '/var/www/moodledata';
    \$CFG->directorypermissions = 02777;
    \$CFG->admin = 'admin';
    
    // Use Redis for session handling
    \$CFG->session_handler_class = '\core\session\redis';
    \$CFG->session_redis_host = '${elasticache_endpoint}';
    \$CFG->session_redis_port = 6379;
    \$CFG->session_redis_database = 0;
    \$CFG->session_redis_prefix = 'moodle_session_';
    
    // Use Redis for caching
    \$CFG->cache_store_backends[] = array(
        'name'          => 'Redis',
        'type'          => 'redis',
        'plugin'        => 'redis',
        'server'        => '${elasticache_endpoint}',
        'prefix'        => 'moodle_cache_',
        'serializer'    => 1,
    );
    
    // Set default cache
    \$CFG->cache_stores = array(
        array(
            'name'          => 'Redis',
            'plugin'        => 'redis',
            'configuration' => array(
                'server'        => '${elasticache_endpoint}',
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
echo "Configuring Redis for PHP..."
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
echo "Restarting Apache..."
systemctl restart httpd

# Setup cron job for Moodle
echo "Setting up cron jobs..."
echo "*/15 * * * * apache /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null 2>&1" > /etc/cron.d/moodle

# Setup daily backup to S3
cat > /usr/local/bin/moodle-backup.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/moodle-backup-$TIMESTAMP"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup Moodle database
mysqldump -h ${db_host} -u ${db_username} -p${db_password} ${db_name} > $BACKUP_DIR/moodle-db.sql

# Compress backup
tar -czf $BACKUP_DIR/moodle-backup-$TIMESTAMP.tar.gz -C $BACKUP_DIR moodle-db.sql

# Upload to S3
aws s3 cp $BACKUP_DIR/moodle-backup-$TIMESTAMP.tar.gz s3://${s3_bucket}/daily-backups/

# Cleanup
rm -rf $BACKUP_DIR
EOF

chmod +x /usr/local/bin/moodle-backup.sh
echo "0 2 * * * root /usr/local/bin/moodle-backup.sh >/dev/null 2>&1" > /etc/cron.d/moodle-backup

# Optimize OS settings for web server
cat >> /etc/sysctl.conf << 'EOF'
# Increase system file descriptor limit
fs.file-max = 65535

# Optimize network settings
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
EOF

sysctl -p

# Set system limits for the Apache user
cat > /etc/security/limits.d/apache.conf << 'EOF'
apache soft nofile 65535
apache hard nofile 65535
EOF

echo "Moodle 5.0 installation completed successfully!"