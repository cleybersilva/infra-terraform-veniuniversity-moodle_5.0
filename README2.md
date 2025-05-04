# Pipeline de Infraestrutura para Moodle 5.0 na AWS

Este repositório contém a configuração da infraestrutura como código (IaC) para o Moodle 5.0, implementando uma pipeline completa no GitHub Actions para implantação nos ambientes de desenvolvimento, homologação e produção.

## Estrutura do Projeto

```
infra/
├── envs/                  # Variáveis específicas de cada ambiente
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── hom/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
├── main.tf                # Configuração principal do Terraform
├── variables.tf           # Definição de variáveis
├── outputs.tf             # Outputs da infraestrutura
├── versions.tf            # Restrições de versão
├── secrets.tf             # Gerenciamento de credenciais
├── monitoring.tf          # Configuração de monitoramento
├── waf.tf                 # Configuração do WAF
└── route53.tf             # Configuração de DNS
```

## Ambientes

A infraestrutura suporta três ambientes distintos:

- **Desenvolvimento (dev)**: Ambiente de menor escala para testes iniciais e desenvolvimento.
- **Homologação (hom)**: Ambiente para testes de aceitação, homologação e validação antes da produção.
- **Produção (prod)**: Ambiente de produção com alta disponibilidade e segurança reforçada.

## Pipeline no GitHub Actions

A pipeline de CI/CD implementa o seguinte fluxo:

### 1. Pipeline Principal (`terraform.yml`)

- **Gatilhos**:
  - Push para as branches `main` ou `develop`
  - Pull Requests para as branches `main` ou `develop`
  - Acionamento manual via `workflow_dispatch`

- **Fluxo**:
  - **Validação**: Verifica a formatação e valida a configuração do Terraform
  - **Deploy em Dev**: Automático quando merge na branch `develop`
  - **Deploy em Homologação**: Quando há merge na `main` com tag `[deploy-hom]`
  - **Deploy em Produção**: Quando há merge na `main` com tag `[deploy-prod]`, com aprovação manual

### 2. Pipeline de Destruição (`terraform-destroy.yml`)

- **Gatilhos**:
  - Apenas acionamento manual via `workflow_dispatch`
  
- **Fluxo**:
  - Requer duas aprovações manuais para confirmação
  - Executa a destruição controlada da infraestrutura

### 3. Rotação de Credenciais (`rotate-credentials.yml`)

- **Gatilhos**:
  - Execução programada a cada 30 dias
  - Acionamento manual para rotação imediata

- **Fluxo**:
  - Rotaciona senhas do banco de dados e do admin do Moodle
  - Gera relatório de segurança

### 4. Atualização de Secrets (`update-secrets.yml`)

- **Gatilhos**:
  - Apenas acionamento manual via `workflow_dispatch`

- **Fluxo**:
  - Atualiza senhas e outros secrets em ambientes específicos

## Como Usar

### Pré-requisitos

1. Bucket S3 para armazenar o estado do Terraform
2. IAM Role com permissões adequadas para a infraestrutura
3. Secrets do GitHub configurados

### Secrets Necessários do GitHub

Configure os seguintes secrets no seu repositório GitHub:

- `AWS_REGION`: Região da AWS para implantação
- `AWS_ROLE_ARN`: ARN da IAM Role para assumir durante a execução
- `TF_STATE_BUCKET`: Nome do bucket S3 para armazenar o estado do Terraform
- `SLACK_WEBHOOK_URL`: URL do webhook do Slack para notificações
- `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`: Configurações SMTP para envio de relatórios
- `SECURITY_EMAIL`: Email para receber relatórios de segurança

### Variables do GitHub

Configure as seguintes variáveis no seu repositório GitHub:

- `PROD_APPROVERS`: Lista de usuários que podem aprovar implantações em produção (separados por vírgula)
- `INFRASTRUCTURE_ADMINS`: Lista de administradores da infraestrutura (separados por vírgula)

## Fluxo de Trabalho

### Desenvolvimento de Novas Features

1. Crie uma branch a partir da `develop`
2. Implemente suas alterações
3. Abra um Pull Request para a branch `develop`
4. Após aprovação e merge, a pipeline implantará automaticamente no ambiente de desenvolvimento

### Promoção para Homologação

1. Abra um Pull Request da `develop` para a `main`
2. Inclua `[deploy-hom]` na mensagem de commit ou título do PR
3. Após aprovação e merge, a pipeline implantará automaticamente no ambiente de homologação

### Promoção para Produção

1. Certifique-se de que as alterações foram testadas em homologação
2. Abra um Pull Request da `develop` para a `main` (ou use a mesma PR de homologação)
3. Inclua `[deploy-prod]` na mensagem de commit ou título do PR
4. Após aprovação e merge, a pipeline solicitará aprovação manual
5. Após aprovação, a pipeline implantará no ambiente de produção

## Monitoramento e Segurança

- **CloudWatch Dashboards**: Criados automaticamente para cada ambiente
- **Alertas**: Configurados para notificar problemas via Slack
- **Rotação de Credenciais**: Automatizada a cada 30 dias
- **WAF**: Configurado para proteger contra ataques comuns
- **Secrets Manager**: Utilizado para armazenar credenciais de forma segura

## Contribuições

Para contribuir com melhorias na infraestrutura:

1. Faça fork do repositório
2. Crie uma branch com sua feature/correção
3. Envie um Pull Request para a branch `develop`