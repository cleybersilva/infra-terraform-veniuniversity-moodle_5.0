# Infraestrutura do Moodle 5.0 na AWS com Terraform

Este projeto contém a configuração de infraestrutura como código (IaC) para implantar o Moodle 5.0 na AWS usando Terraform. A arquitetura é projetada para alta disponibilidade, segurança e escalabilidade.

## Arquitetura

A infraestrutura inclui os seguintes componentes:

- **VPC** - Rede virtual privada com subnets públicas e privadas em múltiplas zonas de disponibilidade
- **EC2** - Instâncias em um Auto Scaling Group para hospedar o Moodle
- **RDS** - Banco de dados MySQL Multi-AZ para armazenar os dados do Moodle
- **ElastiCache** - Cluster Redis para cache de sessão e aplicação
- **EFS** - Sistema de arquivos compartilhado para armazenar arquivos do Moodle
- **ALB** - Application Load Balancer para distribuir o tráfego
- **CloudFront** - CDN para entrega de conteúdo estático
- **S3** - Armazenamento de objetos para backups e arquivos
- **WAF** - Firewall de aplicação web para proteção contra ataques
- **CloudWatch** - Monitoramento e alertas
- **Route53** - Configuração de DNS (opcional)
- **Secrets Manager** - Gerenciamento de credenciais

## Requisitos

- Terraform 1.0.0 ou superior
- AWS CLI configurado com as credenciais apropriadas
- Visual Studio Code (para edição dos arquivos Terraform)

## Estrutura de Arquivos

- `main.tf` - Definição principal da infraestrutura
- `variables.tf` - Variáveis configuráveis
- `outputs.tf` - Saídas da infraestrutura
- `versions.tf` - Configuração de versões do Terraform e provedores
- `secrets.tf` - Gerenciamento de credenciais
- `monitoring.tf` - Configuração de monitoramento e alertas
- `waf.tf` - Configuração do WAF
- `route53.tf` - Configuração de DNS (opcional)
- `userdata.sh` - Script de inicialização das instâncias EC2

## Diagrama da Arquitetura

O diagrama da arquitetura está disponível no arquivo `diagrama-arquitetura.mermaid`.

## Como usar

### 1. Clone este repositório

```bash
git clone https://github.com/seu-usuario/moodle-aws-terraform.git
cd moodle-aws-terraform
```

### 2. Configure as variáveis

Crie um arquivo `terraform.tfvars` com suas configurações específicas:

```hcl
aws_region = "us-east-1"
project_name = "moodle"
environment = "prod"
domain_name = "moodle.example.com"
enable_ssl = true
db_password = "sua-senha-segura"
alert_email = "admin@example.com"
key_name = "sua-chave-ssh"
```

### 3. Inicialize o Terraform

```bash
terraform init
```

### 4. Valide a configuração

```bash
terraform validate
```

### 5. Visualize o plano de execução

```bash
terraform plan
```

### 6. Aplique a configuração

```bash
terraform apply
```

### 7. Acesse o Moodle

Após a implantação, você pode acessar o Moodle através do domínio configurado ou do endpoint do CloudFront fornecido nas saídas do Terraform.

## Manutenção e Operação

### Backups

Backups automatizados diários são configurados para:

- RDS: Backups automáticos com retenção configurável
- S3: Política de ciclo de vida para armazenar backups

### Monitoramento

- CloudWatch Dashboards para visualização do desempenho
- Alertas configurados para CPU, memória, disco e erros da aplicação

### Escalabilidade

- Auto Scaling Group para adicionar ou remover instâncias EC2 conforme necessário
- RDS com armazenamento escalável automaticamente

### Segurança

- WAF para proteção contra ataques comuns
- Secrets Manager para gerenciamento seguro de credenciais
- Subnets privadas para recursos críticos
- Security Groups restritos

## Personalização

### Modificação do tema ou plugins do Moodle

Para customizar o Moodle com temas ou plugins adicionais, você pode:

1. Modificar o script `userdata.sh` para incluir a instalação de plugins
2. Ou criar um AMI personalizada pré-configurada com seus plugins

### Configuração de SSL/TLS

Para habilitar HTTPS:

1. Defina `enable_ssl = true` nas variáveis
2. Forneça um domínio válido em `domain_name`
3. O Terraform gerenciará automaticamente o certificado ACM e a configuração do CloudFront

## Custos

Esteja ciente dos custos associados a esta infraestrutura:

- EC2: Instâncias t3.medium em um ASG ($~70/mês por instância)
- RDS: Instância db.t3.medium Multi-AZ ($~170/mês)
- ElastiCache: Instância cache.t3.small ($~50/mês)
- EFS: Armazenamento ($0.30/GB/mês)
- S3: Armazenamento e transferência ($0.023/GB/mês)
- CloudFront: Transferência de dados ($0.085/GB)
- ALB: Taxa horária ($~20/mês)
- Outros serviços: WAF, CloudWatch, Route53, Secrets Manager

Total estimado: ~$400-500/mês para um ambiente de produção médio

## Solução de Problemas

### Problemas comuns

1. **Falha na criação de recursos**:
   - Verifique as permissões do IAM
   - Verifique os limites de serviço da AWS

2. **Problemas de conectividade**:
   - Verifique os security groups
   - Verifique as ACLs de rede

3. **Moodle não inicializa**:
   - Verifique os logs do CloudWatch
   - Verifique se o EFS foi montado corretamente

### Logs e Diagnóstico

- Logs do Moodle: `/var/www/moodledata/moodle.log`
- Logs do Apache: `/var/log/httpd/moodle_error.log`
- Logs de inicialização: `/var/log/user-data.log`

## Contribuições

Contribuições são bem-vindas! Por favor, envie um Pull Request ou abra uma Issue no GitHub.

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo LICENSE para detalhes.