# Pipeline para Moodle 5.0 na AWS com GitHub Actions
Desenvolvi uma pipeline completa para automatizar a implantação da infraestrutura do Moodle 5.0 na AWS usando GitHub Actions, seguindo as melhores práticas de CI/CD e GitOps para gerenciamento dos ambientes de desenvolvimento, homologação e produção.
Arquivos da Pipeline

terraform.yml: Pipeline principal que gerencia todo o ciclo de validação e implantação da infraestrutura nos três ambientes.
terraform-destroy.yml: Pipeline para destruição controlada da infraestrutura, com múltiplos níveis de aprovação para evitar exclusões acidentais.
rotate-credentials.yml: Automatiza a rotação periódica de credenciais seguindo boas práticas de segurança.
update-secrets.yml: Permite atualizações manuais e controladas dos segredos em cada ambiente.

## Fluxo de Implantação
A pipeline implementa um fluxo GitOps completo:

Ambiente de Desenvolvimento: Implantação automática após merge na branch develop
Ambiente de Homologação: Implantação após merge na branch main com tag [deploy-hom]
Ambiente de Produção: Implantação após aprovação manual e tag [deploy-prod]

## Recursos de Segurança

Múltiplas aprovações: Exige confirmação de múltiplos usuários para alterações críticas
Rotação automática de credenciais: A cada 30 dias, com relatórios de segurança
Notificações: Integração com Slack para alertas de segurança e operações
Secrets protegidos: Armazenamento seguro no AWS Secrets Manager

Personalização por Ambiente
Cada ambiente possui seu próprio conjunto de variáveis em infra/envs/{ambiente}/terraform.tfvars, permitindo customização específica:

Dev: Configuração com menor escala e custo para desenvolvimento
Homologação: Configuração intermediária para testes de aceitação
Produção: Configuração robusta para ambiente de produção

A documentação completa do fluxo de trabalho foi disponibilizada no arquivo README.md para garantir que todos os membros da equipe possam entender e operar a pipeline corretamente.Tentar novamenteO Claude pode cometer erros. Confira sempre as respostas. 3.7 Sonnet