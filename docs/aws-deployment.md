# Deploy AWS - AgroValue N8N

Este guia detalha como fazer o deploy do n8n na AWS de forma econômica e escalável.

## Arquitetura AWS

```
┌─────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────────┐ │
│  │   CloudFront    │    │         Route 53 (DNS)              │ │
│  │    (Opcional)   │    │                                     │ │
│  └─────────────────┘    └─────────────────────────────────────┘ │
│           │                              │                     │
├───────────┼──────────────────────────────┼─────────────────────┤
│           │              VPC             │                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │        ┌─────────────────────────────────────────────────┐  │ │
│  │        │             Public Subnets                    │  │ │
│  │        │  ┌─────────────────┐  ┌─────────────────────┐  │  │ │
│  │        │  │       ALB       │  │    NAT Gateway     │  │  │ │
│  │        │  └─────────────────┘  └─────────────────────┘  │  │ │
│  │        └─────────────────────────────────────────────────┘  │ │
│  │                                │                           │ │
│  │        ┌─────────────────────────────────────────────────┐  │ │
│  │        │            Private Subnets                     │  │ │
│  │        │  ┌─────────────────┐  ┌─────────────────────┐  │  │ │
│  │        │  │   ECS Fargate   │  │   ECS Fargate      │  │  │ │
│  │        │  │     (n8n)       │  │     (n8n)          │  │  │ │
│  │        │  └─────────────────┘  └─────────────────────┘  │  │ │
│  │        └─────────────────────────────────────────────────┘  │ │
│  │                                │                           │ │
│  │        ┌─────────────────────────────────────────────────┐  │ │
│  │        │           Database Subnets                     │  │ │
│  │        │  ┌─────────────────┐  ┌─────────────────────┐  │  │ │
│  │        │  │   RDS Primary   │  │   RDS Standby      │  │  │ │
│  │        │  │   (PostgreSQL)  │  │   (PostgreSQL)     │  │  │ │
│  │        │  └─────────────────┘  └─────────────────────┘  │  │ │
│  │        └─────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ Serviços Complementares:                                       │
│ • Secrets Manager (credenciais)                               │
│ • CloudWatch (logs e métricas)                               │
│ • S3 (armazenamento)                                         │
│ • SNS (alertas)                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Pré-requisitos

### 1. Ferramentas Necessárias

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# jq (para processamento JSON)
sudo apt install jq
```

### 2. Configurar Credenciais AWS

```bash
# Configurar perfil AWS
aws configure

# Ou usar variáveis de ambiente
export AWS_ACCESS_KEY_ID="sua_access_key"
export AWS_SECRET_ACCESS_KEY="sua_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Configurar Variáveis de Ambiente

```bash
# Copiar arquivo de produção
cp configs/.env.example configs/.env.production

# Editar configurações críticas
nano configs/.env.production
```

**Variáveis obrigatórias:**

```bash
# Segurança - ALTERE ESTAS SENHAS!
N8N_BASIC_AUTH_PASSWORD=senha_super_segura_123
N8N_ENCRYPTION_KEY=chave_criptografia_32_caracteres_min
DB_POSTGRESDB_PASSWORD=senha_database_muito_segura

# Domínio (opcional, mas recomendado)
N8N_HOST=n8n.seudominio.com
SSL_CERTIFICATE_ARN=arn:aws:acm:us-east-1:123456789:certificate/abc-123

# AWS
AWS_REGION=us-east-1
```

## Deploy Passo a Passo

### 1. Validação Inicial

```bash
# Verificar credenciais AWS
aws sts get-caller-identity

# Verificar region
aws configure get region

# Testar permissões
aws ec2 describe-vpcs --region us-east-1
```

### 2. Executar Deploy

```bash
# Tornar script executável
chmod +x scripts/deploy-aws.sh

# Executar deploy
./scripts/deploy-aws.sh
```

O script irá:
1. ✅ Verificar pré-requisitos
2. 📄 Validar configurações
3. 🏗️ Inicializar Terraform
4. 📋 Mostrar plano de execução
5. 🚀 Executar deploy
6. 📊 Mostrar informações finais

### 3. Configuração de Domínio (Opcional)

#### Certificado SSL

```bash
# Solicitar certificado ACM
aws acm request-certificate \
    --domain-name n8n.seudominio.com \
    --validation-method DNS \
    --region us-east-1

# Configurar validação DNS
# (seguir instruções do console AWS)
```

#### DNS Configuration

```bash
# Criar record no Route 53
aws route53 change-resource-record-sets \
    --hosted-zone-id Z123456789 \
    --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "n8n.seudominio.com",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [{
                    "Value": "ALB-DNS-NAME"
                }]
            }
        }]
    }'
```

## Componentes Criados

### Networking

- **VPC**: Rede isolada com CIDR 10.0.0.0/16
- **Subnets**: 
  - Públicas: 10.0.1.0/24, 10.0.2.0/24
  - Privadas: 10.0.10.0/24, 10.0.11.0/24
  - Database: 10.0.20.0/24, 10.0.21.0/24
- **NAT Gateways**: Para acesso internet das subnets privadas
- **Security Groups**: Configurações restritivas de firewall

### Compute

- **ECS Cluster**: Cluster Fargate para containers
- **ECS Service**: Serviço n8n com auto-scaling
- **Application Load Balancer**: Distribuição de carga e SSL

### Database

- **RDS PostgreSQL**: Banco gerenciado com backup automático
- **Performance Insights**: Monitoramento avançado
- **Multi-AZ**: Alta disponibilidade (opcional)

### Storage & Security

- **S3 Bucket**: Armazenamento de dados com lifecycle
- **Secrets Manager**: Gerenciamento seguro de credenciais
- **CloudWatch**: Logs e métricas centralizados

## Otimizações de Custo

### 1. Instâncias Spot (Habilitadas por Padrão)

```hcl
# Configuração no Terraform
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight           = 100
  base             = 0
}
```

**Economia**: Até 70% de redução nos custos de compute

### 2. Auto Scaling Inteligente

```hcl
# Configuração de auto scaling
target_tracking_scaling_policy_configuration {
  target_value = 70  # CPU target
  scale_in_cooldown  = 300
  scale_out_cooldown = 300
}
```

### 3. RDS Otimizado

- **Instância**: db.t3.micro (elegível para free tier)
- **Storage**: GP3 com auto-scaling
- **Backup**: 7 dias de retenção

### 4. Monitoramento de Custos

```bash
# Criar budget AWS
aws budgets create-budget \
    --account-id 123456789012 \
    --budget '{
        "BudgetName": "N8N-Monthly-Budget",
        "BudgetLimit": {
            "Amount": "50",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }'
```

## Estimativa de Custos Mensais

| Componente | Configuração | Custo Estimado |
|------------|-------------|----------------|
| ECS Fargate Spot | 1-2 tasks 0.25 vCPU, 0.5 GB | $15-30 |
| RDS t3.micro | PostgreSQL, 20GB | $15-20 |
| Application Load Balancer | Padrão | $16 |
| NAT Gateway | 2 AZs | $32 |
| Data Transfer | 10GB/mês | $5-10 |
| Storage (S3) | 5GB | $2-5 |
| **Total Estimado** | | **$85-123/mês** |

### Otimizações Avançadas

1. **Scheduled Scaling**: Reduzir capacidade durante off-hours
2. **Reserved Instances**: Para cargas previsíveis
3. **Spot Fleet**: Mix de instâncias para maior economia
4. **CloudWatch Logs Retention**: Ajustar período de retenção

## Monitoramento e Alertas

### Dashboard CloudWatch

O deploy cria automaticamente um dashboard com:
- Métricas de CPU e memória do ECS
- Latência e requests do ALB
- Performance do RDS
- Logs de erro centralizados
- Custos estimados

### Alertas Configurados

1. **CPU Alto**: > 80% por 2 períodos
2. **Memória Alta**: > 85% por 2 períodos
3. **Erro Rate**: > 5% de erros 5xx
4. **Database Connections**: > 80% do limite

### SNS Topics

```bash
# Inscrever email nos alertas
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:123456789:agrovalue-n8n-alerts \
    --protocol email \
    --notification-endpoint seu-email@exemplo.com
```

## Backup e Disaster Recovery

### Backups Automáticos

- **RDS**: Backup diário com 7 dias de retenção
- **S3**: Versionamento habilitado
- **ECS**: Configuração como código (Terraform)

### Restore de Backup

```bash
# Restore RDS de backup
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier n8n-restored \
    --db-snapshot-identifier rds:agrovalue-n8n-database-2024-01-01-03-00

# Restore S3 de versão específica
aws s3api restore-object \
    --bucket agrovalue-n8n-data-xxx \
    --key workflow-backup.json \
    --version-id abc123
```

## Atualizações e Manutenção

### Atualizar N8N

```bash
# Atualizar image tag no Terraform
# terraform/variables.tf
variable "n8n_image" {
  default = "n8nio/n8n:1.19.0"  # Nova versão
}

# Aplicar atualização
cd terraform
terraform plan -var="n8n_image=n8nio/n8n:1.19.0"
terraform apply
```

### Scaling Manual

```bash
# Aumentar capacidade temporariamente
aws ecs update-service \
    --cluster agrovalue-n8n-cluster \
    --service agrovalue-n8n-service \
    --desired-count 3
```

## Solução de Problemas

### Logs de Debug

```bash
# Logs do ECS
aws logs filter-log-events \
    --log-group-name /aws/ecs/agrovalue-n8n \
    --start-time $(date -d '1 hour ago' +%s)000

# Status do serviço
aws ecs describe-services \
    --cluster agrovalue-n8n-cluster \
    --services agrovalue-n8n-service
```

### Health Checks

```bash
# Verificar health do ALB
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...

# Testar conectividade RDS
aws rds describe-db-instances \
    --db-instance-identifier agrovalue-n8n-database
```

### Problemas Comuns

1. **Task não inicia**: Verificar logs ECS e IAM permissions
2. **502 Bad Gateway**: Verificar health check do target group
3. **Database connection**: Verificar security groups e credenciais
4. **High costs**: Revisar métricas CloudWatch e auto-scaling

## Limpeza de Recursos

```bash
# CUIDADO: Remove TODOS os recursos
cd terraform
terraform destroy

# Confirmar exclusão manual de:
# - S3 buckets (se tiverem dados)
# - Snapshots RDS
# - Logs CloudWatch
```

## Próximos Passos

1. ✅ Configurar domínio e SSL
2. 📧 Configurar notificações SNS
3. 🔄 Implementar CI/CD pipeline
4. 📊 Configurar monitoramento avançado
5. 🔒 Implementar WAF (Web Application Firewall)
6. 🌍 Configurar multi-region (se necessário)

---

**⚠️ Importante**: Sempre monitore os custos AWS após o deploy e ajuste recursos conforme necessário. O free tier pode cobrir parte dos custos iniciais.
