# route53.tf - Configuração do DNS para o Moodle

# Criar a zona hospedada se a variável create_hosted_zone for verdadeira
resource "aws_route53_zone" "moodle_zone" {
  count = var.create_hosted_zone && var.domain_name != "" ? 1 : 0
  
  name = var.domain_name
  
  tags = {
    Name        = "${var.project_name}-zone"
    Environment = var.environment
  }
}

# Criar o registro A para o domínio principal apontando para o CloudFront
resource "aws_route53_record" "moodle_cloudfront" {
  count = var.domain_name != "" ? 1 : 0
  
  zone_id = var.create_hosted_zone ? aws_route53_zone.moodle_zone[0].zone_id : var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.moodle.domain_name
    zone_id                = "Z2FDTNDATAQYW2"  # CloudFront zone ID (é fixo para qualquer distribuição CloudFront)
    evaluate_target_health = false
  }
}

# Criar um registro CNAME para o wildcard *.dominio apontando para o domínio principal
resource "aws_route53_record" "moodle_wildcard" {
  count = var.domain_name != "" ? 1 : 0
  
  zone_id = var.create_hosted_zone ? aws_route53_zone.moodle_zone[0].zone_id : var.route53_zone_id
  name    = "*.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}

# Criar certificado ACM para o domínio se enable_ssl for verdadeiro
resource "aws_acm_certificate" "moodle_cert" {
  count = var.enable_ssl && var.domain_name != "" ? 1 : 0
  
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "${var.project_name}-certificate"
    Environment = var.environment
  }
}

# Criar registros de validação DNS para o certificado
resource "aws_route53_record" "moodle_cert_validation" {
  for_each = var.enable_ssl && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.moodle_cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  
  zone_id = var.create_hosted_zone ? aws_route53_zone.moodle_zone[0].zone_id : var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# Validar o certificado
resource "aws_acm_certificate_validation" "moodle_cert" {
  count = var.enable_ssl && var.domain_name != "" ? 1 : 0
  
  certificate_arn         = aws_acm_certificate.moodle_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.moodle_cert_validation : record.fqdn]
}

# Variáveis adicionais necessárias
variable "route53_zone_id" {
  description = "ID da zona Route53 existente (se não estiver criando uma nova)"
  type        = string
  default     = ""
}