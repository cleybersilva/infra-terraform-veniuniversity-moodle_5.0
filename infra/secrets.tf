# secrets.tf - Gerenciamento de credenciais seguras para o Moodle

# AWS Secrets Manager para armazenar as credenciais do banco de dados
resource "aws_secretsmanager_secret" "moodle_db_credentials" {
  name        = "${var.project_name}/${var.environment}/db-credentials"
  description = "Credenciais do banco de dados para a instância Moodle"
  
  tags = {
    Name        = "${var.project_name}-db-credentials"
    Environment = var.environment
  }
}

# Armazenar as credenciais no Secrets Manager
resource "aws_secretsmanager_secret_version" "moodle_db_credentials" {
  secret_id = aws_secretsmanager_secret.moodle_db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
    host     = aws_db_instance.moodle.address
    port     = aws_db_instance.moodle.port
  })
}

# AWS Secrets Manager para armazenar as credenciais de admin do Moodle
resource "aws_secretsmanager_secret" "moodle_admin_credentials" {
  name        = "${var.project_name}/${var.environment}/admin-credentials"
  description = "Credenciais de administrador para o Moodle"
  
  tags = {
    Name        = "${var.project_name}-admin-credentials"
    Environment = var.environment
  }
}

# Gerar uma senha aleatória para o admin do Moodle
resource "random_password" "moodle_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Armazenar as credenciais de admin no Secrets Manager
resource "aws_secretsmanager_secret_version" "moodle_admin_credentials" {
  secret_id = aws_secretsmanager_secret.moodle_admin_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.moodle_admin_password.result
  })
}

# Conceder permissão à instância EC2 para acessar os segredos
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-secrets-access-policy"
  description = "Política para EC2 acessar segredos no Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = [
          aws_secretsmanager_secret.moodle_db_credentials.arn,
          aws_secretsmanager_secret.moodle_admin_credentials.arn
        ]
      }
    ]
  })
}

# Anexar a política de acesso aos segredos à role do EC2
resource "aws_iam_role_policy_attachment" "secrets_access_attachment" {
  role       = aws_iam_role.moodle_ec2_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}