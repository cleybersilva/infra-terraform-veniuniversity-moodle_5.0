# monitoring.tf - Monitoramento e alertas para a infraestrutura do Moodle

# Criar um SNS Topic para alertas de monitoramento
resource "aws_sns_topic" "moodle_alerts" {
  name = "${var.project_name}-alerts"
  
  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}

# Criar uma subscrição de email para o SNS Topic
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.moodle_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarme de disco cheio nas instâncias EC2
resource "aws_cloudwatch_metric_alarm" "disk_usage_high" {
  alarm_name          = "${var.project_name}-disk-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alerta quando o uso de disco ultrapassar 85%"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.moodle.name,
    path                 = "/"
  }
}

# Alarme de uso alto de memória nas instâncias EC2
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta quando o uso de memória ultrapassar 80%"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.moodle.name
  }
}

# Alarme de uso alto de CPU no RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta quando o uso de CPU do RDS ultrapassar 80%"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.moodle.id
  }
}

# Alarme de uso alto de espaço de armazenamento no RDS
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project_name}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5000000000  # 5 GB em bytes
  alarm_description   = "Alerta quando o espaço livre no RDS for menor que 5GB"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.moodle.id
  }
}

# Alarme de uso alto de CPU no ElastiCache
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_high" {
  alarm_name          = "${var.project_name}-elasticache-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta quando o uso de CPU do ElastiCache ultrapassar 80%"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    CacheClusterId = aws_elasticache_cluster.moodle.id
  }
}

# Alarme de memória do ElastiCache
resource "aws_cloudwatch_metric_alarm" "elasticache_memory_high" {
  alarm_name          = "${var.project_name}-elasticache-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alerta quando o uso de memória do ElastiCache ultrapassar 80%"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    CacheClusterId = aws_elasticache_cluster.moodle.id
  }
}

# Alarme de erros HTTP 5xx no Application Load Balancer
resource "aws_cloudwatch_metric_alarm" "alb_error_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alerta quando o número de erros 5XX no ALB ultrapassar 10 em 5 minutos"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.moodle.arn_suffix
  }
}

# Alarme de erros HTTP 4xx no Application Load Balancer
resource "aws_cloudwatch_metric_alarm" "alb_error_4xx" {
  alarm_name          = "${var.project_name}-alb-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alerta quando o número de erros 4XX no ALB ultrapassar 100 em 5 minutos"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.moodle.arn_suffix
  }
}

# Alarme de falhas nas verificações de saúde no Target Group
resource "aws_cloudwatch_metric_alarm" "target_group_health" {
  alarm_name          = "${var.project_name}-target-health-check-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alerta quando houver instâncias não saudáveis no target group"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.moodle.arn_suffix,
    TargetGroup  = aws_lb_target_group.moodle.arn_suffix
  }
}

# Alarme para erros no WAF
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.project_name}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alerta quando o WAF bloquear mais de 100 requisições em 5 minutos"
  alarm_actions       = [aws_sns_topic.moodle_alerts.arn]
  
  dimensions = {
    WebACL = aws_wafv2_web_acl.moodle_waf.name,
    Region = var.aws_region
  }
}

# CloudWatch Dashboard para monitoramento geral
resource "aws_cloudwatch_dashboard" "moodle_monitoring" {
  dashboard_name = "${var.project_name}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.moodle.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CWAgent", "mem_used_percent", "AutoScalingGroupName", aws_autoscaling_group.moodle.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 Memory Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.moodle.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.moodle.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Free Storage Space"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_cluster.moodle.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ElastiCache CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.moodle.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.moodle.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", aws_lb.moodle.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Error Codes"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.moodle_waf.name, "Region", var.aws_region]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "WAF Blocked Requests"
        }
      }
    ]
  })
}