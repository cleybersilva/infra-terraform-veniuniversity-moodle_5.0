# Makefile para automação da implantação do Moodle na AWS

.PHONY: help init validate fmt plan apply destroy output clean

# Variáveis
TERRAFORM_VERSION=1.0.0
AWS_REGION=$(shell grep aws_region terraform.tfvars 2>/dev/null | cut -d '=' -f2 | tr -d ' "' || echo "us-east-1")
ENV=$(shell grep environment terraform.tfvars 2>/dev/null | cut -d '=' -f2 | tr -d ' "' || echo "prod")

# Cores
GREEN=\033[0;32m
RED=\033[0;31m
YELLOW=\033[0;33m
NC=\033[0m

# Ajuda
help:
	@echo -e "$(GREEN)Moodle 5.0 na AWS - Comandos disponíveis:$(NC)"
	@echo -e "  $(YELLOW)make check$(NC)        - Verifica as dependências"
	@echo -e "  $(YELLOW)make init$(NC)         - Inicializa o Terraform"
	@echo -e "  $(YELLOW)make fmt$(NC)          - Formata os arquivos Terraform"
	@echo -e "  $(YELLOW)make validate$(NC)     - Valida a configuração"
	@echo -e "  $(YELLOW)make plan$(NC)         - Cria o plano de execução"
	@echo -e "  $(YELLOW)make apply$(NC)        - Aplica o plano (implanta a infraestrutura)"
	@echo -e "  $(YELLOW)make output$(NC)       - Mostra informações da infraestrutura"
	@echo -e "  $(YELLOW)make destroy$(NC)      - Destrói a infraestrutura"
	@echo -e "  $(YELLOW)make clean$(NC)        - Remove arquivos temporários"
	@echo -e "  $(YELLOW)make deploy$(NC)       - Implanta tudo (init, validate, plan, apply, output)"
	@echo ""
	@echo -e "  $(GREEN)Configuração atual:$(NC)"
	@echo -e "  $(YELLOW)Região AWS:$(NC) $(AWS_REGION)"
	@echo -e "  $(YELLOW)Ambiente:$(NC) $(ENV)"

# Verificar dependências
check:
	@echo -e "$(GREEN)Verificando dependências...$(NC)"
	@terraform version | grep -q "Terraform v" || { echo -e "$(RED)Terraform não encontrado. Instale o Terraform v$(TERRAFORM_VERSION)+$(NC)"; exit 1; }
	@aws --version | grep -q "aws-cli" || { echo -e "$(RED)AWS CLI não encontrado. Instale o AWS CLI$(NC)"; exit 1; }
	@aws sts get-caller-identity > /dev/null || { echo -e "$(RED)Credenciais da AWS não configuradas ou inválidas. Execute 'aws configure'$(NC)"; exit 1; }
	@echo -e "$(GREEN)Todas as dependências estão satisfeitas.$(NC)"
	@if [ ! -f terraform.tfvars ]; then \
		echo -e "$(YELLOW)Arquivo terraform.tfvars não encontrado.$(NC)"; \
		if [ -f terraform.tfvars.example ]; then \
			echo -e "$(YELLOW)Criando a partir do exemplo...$(NC)"; \
			cp terraform.tfvars.example terraform.tfvars; \
			echo -e "$(GREEN)Arquivo terraform.tfvars criado. Por favor, edite-o com suas configurações específicas.$(NC)"; \
		else \
			echo -e "$(RED)Nem terraform.tfvars nem terraform.tfvars.example foram encontrados.$(NC)"; \
			exit 1; \
		fi \
	else \
		echo -e "$(GREEN)Arquivo terraform.tfvars encontrado.$(NC)"; \
	fi

# Inicializar o Terraform
init: check
	@echo -e "$(GREEN)Inicializando o Terraform...$(NC)"
	terraform init

# Formatar os arquivos Terraform
fmt:
	@echo -e "$(GREEN)Formatando os arquivos Terraform...$(NC)"
	terraform fmt -recursive

# Validar a configuração
validate: init
	@echo -e "$(GREEN)Validando a configuração do Terraform...$(NC)"
	terraform validate

# Criar o plano de execução
plan: validate
	@echo -e "$(GREEN)Criando plano do Terraform...$(NC)"
	terraform plan -out=tfplan

# Aplicar o plano
apply:
	@if [ ! -f tfplan ]; then \
		echo -e "$(RED)Arquivo de plano 'tfplan' não encontrado. Execute 'make plan' primeiro.$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)Aplicando o plano do Terraform...$(NC)"
	terraform apply tfplan

# Exibir informações da infraestrutura
output:
	@echo -e "$(GREEN)Exibindo informações da infraestrutura:$(NC)"
	@echo ""
	@echo -e "$(GREEN)CloudFront Domain:$(NC) $$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo 'N/A')"
	@echo -e "$(GREEN)ALB DNS:$(NC) $$(terraform output -raw alb_dns_name 2>/dev/null || echo 'N/A')"
	@echo -e "$(GREEN)RDS Endpoint:$(NC) $$(terraform output -raw rds_endpoint 2>/dev/null || echo 'N/A')"
	@echo -e "$(GREEN)ElastiCache Endpoint:$(NC) $$(terraform output -raw elasticache_endpoint 2>/dev/null || echo 'N/A')"
	@echo -e "$(GREEN)EFS DNS:$(NC) $$(terraform output -raw efs_dns_name 2>/dev/null || echo 'N/A')"
	@echo ""
	@DOMAIN_NAME=$$(grep "domain_name" terraform.tfvars 2>/dev/null | cut -d '=' -f2 | tr -d ' "' || echo ""); \
	if [ -n "$$DOMAIN_NAME" ] && [ "$$DOMAIN_NAME" != '""' ]; then \
		echo -e "$(GREEN)URL do Moodle:$(NC) https://$$DOMAIN_NAME"; \
	else \
		echo -e "$(GREEN)URL do Moodle:$(NC) https://$$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo 'N/A')"; \
	fi
	@echo ""
	@echo -e "$(YELLOW)Aguarde alguns minutos para que a instância seja inicializada e o Moodle seja configurado.$(NC)"

# Destruir a infraestrutura
destroy:
	@echo -e "$(RED)ATENÇÃO: Esta ação irá destruir toda a infraestrutura criada!$(NC)"
	@read -p "Tem certeza que deseja continuar? (sim/não): " CONFIRM; \
	if [ "$$CONFIRM" != "sim" ]; then \
		echo -e "$(GREEN)Operação cancelada.$(NC)"; \
		exit 0; \
	fi
	@echo -e "$(YELLOW)Destruindo a infraestrutura...$(NC)"
	terraform destroy -auto-approve

# Remover arquivos temporários
clean:
	@echo -e "$(GREEN)Removendo arquivos temporários...$(NC)"
	rm -f tfplan
	rm -f .terraform.lock.hcl
	rm -rf .terraform

# Implantação completa
deploy: init fmt validate plan apply output
	@echo -e "$(GREEN)Implantação concluída com sucesso!$(NC)"