# waf.tf - Configuração do AWS WAF para proteger a aplicação Moodle

# Criar um Web ACL para proteger o Application Load Balancer e o CloudFront
resource "aws_wafv2_web_acl" "moodle_waf" {
  name        = "${var.project_name}-waf-acl"
  description = "WAF Web ACL para o Moodle"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Regra para limitar a taxa de requisições
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Regra para bloquear SQL Injection
  rule {
    name     = "SQLInjectionRule"
    priority = 2

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          sqli_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          sqli_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sql-injection"
      sampled_requests_enabled   = true
    }
  }

  # Regra para bloquear Cross-Site Scripting (XSS)
  rule {
    name     = "XSSRule"
    priority = 3

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-xss"
      sampled_requests_enabled   = true
    }
  }

  # Regra para bloquear paths específicos do Moodle que não devem ser acessados diretamente
  rule {
    name     = "PathRestrictionsRule"
    priority = 4

    action {
      block {}
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.restricted_paths.arn
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-path-restrictions"
      sampled_requests_enabled   = true
    }
  }

  # Configuração de visibilidade geral para o WAF
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-waf-acl"
    Environment = var.environment
  }
}

# Criar conjunto de padrões regex para caminhos restritos
resource "aws_wafv2_regex_pattern_set" "restricted_paths" {
  name        = "${var.project_name}-restricted-paths"
  description = "Caminhos restritos do Moodle"
  scope       = "REGIONAL"

  regular_expression {
    regex_string = "^/config\\.php$"
  }

  regular_expression {
    regex_string = "^/lib/"
  }

  regular_expression {
    regex_string = "^/admin/cli/"
  }

  regular_expression {
    regex_string = "^/backup/"
  }

  regular_expression {
    regex_string = "^/vendor/"
  }

  tags = {
    Name        = "${var.project_name}-restricted-paths"
    Environment = var.environment
  }
}

# Associar o WAF Web ACL ao Application Load Balancer
resource "aws_wafv2_web_acl_association" "moodle_alb" {
  resource_arn = aws_lb.moodle.arn
  web_acl_arn  = aws_wafv2_web_acl.moodle_waf.arn
}

# Criar um grupo de logs para o WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-waf-logs"
    Environment = var.environment
  }
}

# Configurar o logging para o WAF
resource "aws_wafv2_web_acl_logging_configuration" "moodle_waf" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.moodle_waf.arn
}