#!/bin/bash
# Script para facilitar a implantação da infraestrutura do Moodle na AWS

set -e

# Cores para melhor visualização
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sem cor

# Função para exibir mensagens
print_message() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Função para verificar dependências
check_dependencies() {
  print_message "Verificando dependências..."
  
  # Verificar se o Terraform está instalado
  if ! command -v terraform &> /dev/null; then
    print_error "Terraform não encontrado. Por favor, instale o Terraform: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
  fi
  
  # Verificar a versão do Terraform
  TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
  REQUIRED_VERSION="1.0.0"
  
  if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$TERRAFORM_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
    print_warning "Versão do Terraform é $TERRAFORM_VERSION, mas é recomendado $REQUIRED_VERSION ou superior."
  else
    print_message "Terraform $TERRAFORM_VERSION instalado corretamente."
  fi
  
  # Verificar se o AWS CLI está instalado
  if ! command -v aws &> /dev/null; then
    print_error "AWS CLI não encontrado. Por favor, instale o AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
  fi
  
  # Verificar se as credenciais da AWS estão configuradas
  if ! aws sts get-caller-identity &> /dev/null; then
    print_error "Credenciais da AWS não configuradas ou inválidas. Execute 'aws configure'."
    exit 1
  fi
  
  print_message "Todas as dependências estão satisfeitas."
}

# Função para verificar e criar o arquivo terraform.tfvars
check_tfvars() {
  print_message "Verificando arquivo terraform.tfvars..."
  
  if [ ! -f "terraform.tfvars" ]; then
    if [ -f "terraform.tfvars.example" ]; then
      print_warning "Arquivo terraform.tfvars não encontrado. Criando a partir do exemplo."
      cp terraform.tfvars.example terraform.tfvars
      print_message "Arquivo terraform.tfvars criado. Por favor, edite-o com suas configurações específicas."
      exit 0
    else
      print_error "Nem terraform.tfvars nem terraform.tfvars.example foram encontrados. Verifique se você está no diretório correto."
      exit 1
    fi
  else
    print_message "Arquivo terraform.tfvars encontrado."
  fi
}

# Função para inicializar o Terraform
init_terraform() {
  print_message "Inicializando o Terraform..."
  terraform init
  
  if [ $? -ne 0 ]; then
    print_error "Falha ao inicializar o Terraform. Verifique o erro acima."
    exit 1
  fi
  
  print_message "Terraform inicializado com sucesso."
}

# Função para validar a configuração
validate_terraform() {
  print_message "Validando a configuração do Terraform..."
  terraform validate
  
  if [ $? -ne 0 ]; then
    print_error "Falha na validação do Terraform. Corrija os erros antes de continuar."
    exit 1
  fi
  
  print_message "Configuração do Terraform validada com sucesso."
}

# Função para criar o plano do Terraform
plan_terraform() {
  print_message "Criando plano do Terraform..."
  terraform plan -out=tfplan
  
  if [ $? -ne 0 ]; then
    print_error "Falha ao criar o plano do Terraform. Verifique o erro acima."
    exit 1
  fi
  
  print_message "Plano do Terraform criado com sucesso."
}

# Função para aplicar o plano do Terraform
apply_terraform() {
  print_message "Aplicando o plano do Terraform..."
  terraform apply "tfplan"
  
  if [ $? -ne 0 ]; then
    print_error "Falha ao aplicar o plano do Terraform. Verifique o erro acima."
    exit 1
  fi
  
  print_message "Infraestrutura implantada com sucesso!"
}

# Função para exibir as saídas do Terraform
show_outputs() {
  print_message "Exibindo informações da infraestrutura:"
  echo ""
  
  # CloudFront Domain
  CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "N/A")
  echo -e "${GREEN}CloudFront Domain:${NC} $CLOUDFRONT_DOMAIN"
  
  # ALB DNS
  ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
  echo -e "${GREEN}ALB DNS:${NC} $ALB_DNS"
  
  # RDS Endpoint
  RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "N/A")
  echo -e "${GREEN}RDS Endpoint:${NC} $RDS_ENDPOINT"
  
  # ElastiCache Endpoint
  ELASTICACHE_ENDPOINT=$(terraform output -raw elasticache_endpoint 2>/dev/null || echo "N/A")
  echo -e "${GREEN}ElastiCache Endpoint:${NC} $ELASTICACHE_ENDPOINT"
  
  # EFS DNS
  EFS_DNS=$(terraform output -raw efs_dns_name 2>/dev/null || echo "N/A")
  echo -e "${GREEN}EFS DNS:${NC} $EFS_DNS"
  
  echo ""
  print_message "Para acessar o Moodle, use a URL:"
  
  # Verificar se existe um domínio personalizado
  DOMAIN_NAME=$(grep "domain_name" terraform.tfvars | cut -d '=' -f2 | tr -d ' "' || echo "")
  
  if [ -n "$DOMAIN_NAME" ] && [ "$DOMAIN_NAME" != '""' ]; then
    echo -e "${GREEN}https://$DOMAIN_NAME${NC}"
  else
    echo -e "${GREEN}https://$CLOUDFRONT_DOMAIN${NC}"
  fi
  
  echo ""
  print_message "Aguarde alguns minutos para que a instância seja inicializada e o Moodle seja configurado."
}

# Função para destruir a infraestrutura
destroy_terraform() {
  print_warning "ATENÇÃO: Esta ação irá destruir toda a infraestrutura criada!"
  read -p "Tem certeza que deseja continuar? (sim/não): " CONFIRM
  
  if [ "$CONFIRM" != "sim" ]; then
    print_message "Operação cancelada."
    exit 0
  fi
  
  print_message "Destruindo a infraestrutura..."
  terraform destroy -auto-approve
  
  if [ $? -ne 0 ]; then
    print_error "Falha ao destruir a infraestrutura. Verifique o erro acima."
    exit 1
  fi
  
  print_message "Infraestrutura destruída com sucesso."
}

# Menu principal
display_menu() {
  echo -e "${GREEN}==============================================${NC}"
  echo -e "${GREEN}    Implantação do Moodle 5.0 na AWS        ${NC}"
  echo -e "${GREEN}==============================================${NC}"
  echo ""
  echo -e "1) Verificar dependências"
  echo -e "2) Inicializar Terraform"
  echo -e "3) Validar configuração"
  echo -e "4) Criar plano"
  echo -e "5) Aplicar plano"
  echo -e "6) Mostrar informações da infraestrutura"
  echo -e "7) Destruir infraestrutura"
  echo -e "8) Implantar tudo (passos 1-6)"
  echo -e "9) Sair"
  echo ""
  read -p "Escolha uma opção: " OPTION
  
  case $OPTION in
    1) check_dependencies; check_tfvars; display_menu;;
    2) init_terraform; display_menu;;
    3) validate_terraform; display_menu;;
    4) plan_terraform; display_menu;;
    5) apply_terraform; display_menu;;
    6) show_outputs; display_menu;;
    7) destroy_terraform; display_menu;;
    8) 
       check_dependencies
       check_tfvars
       init_terraform
       validate_terraform
       plan_terraform
       apply_terraform
       show_outputs
       display_menu
       ;;
    9) exit 0;;
    *) print_error "Opção inválida!"; display_menu;;
  esac
}

# Executar o menu
display_menu