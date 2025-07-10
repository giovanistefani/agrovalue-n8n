# Otimização de Custos - AgroValue N8N

Este documento detalha estratégias para minimizar custos de operação do n8n na AWS mantendo performance e confiabilidade.

## 📊 Análise de Custos Atual

### Breakdown de Custos Mensais

| Componente | Configuração Padrão | Custo/Mês | Configuração Otimizada | Custo/Mês | Economia |
|------------|---------------------|------------|------------------------|------------|----------|
| **ECS Fargate** | ON_DEMAND, 0.25 vCPU, 0.5GB | $30-45 | SPOT, 0.25 vCPU, 0.5GB | $10-15 | 67% |
| **RDS PostgreSQL** | db.t3.micro, 20GB | $20 | db.t3.micro, 20GB + Scheduled | $15 | 25% |
| **Load Balancer** | ALB Padrão | $16 | ALB + WAF (opcional) | $16-20 | 0% |
| **NAT Gateway** | 2 AZs | $32 | 1 AZ + Backup | $22 | 31% |
| **Data Transfer** | 10GB/mês | $10 | Otimizado | $5 | 50% |
| **Storage S3** | Standard | $5 | IA + Glacier | $3 | 40% |
| **CloudWatch** | Padrão | $5 | Otimizado | $3 | 40% |
| **Secrets Manager** | 5 secrets | $2 | 5 secrets | $2 | 0% |
| **Total** | | **$120-135** | | **$76-88** | **37%** |

## 🎯 Estratégias de Otimização

### 1. Compute (ECS Fargate)

#### Instâncias Spot (Já Implementado)
```hcl
# terraform/ecs.tf
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight           = 100
  base             = 0
}
```
**Economia**: 60-70% nos custos de compute

#### Scheduled Scaling
```bash
# Escalar para baixo durante off-hours (22:00-06:00)
aws application-autoscaling put-scheduled-action \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/agrovalue-n8n-cluster/agrovalue-n8n-service \
    --scheduled-action-name scale-down-night \
    --schedule "cron(0 22 * * ? *)" \
    --scalable-target-action MinCapacity=0,MaxCapacity=1
```

#### Rightsizing de Recursos
```hcl
# Ajustar para cargas de trabalho menores
variable "ecs_cpu" {
  default = 256  # Reduzido de 512
}

variable "ecs_memory" {
  default = 512  # Reduzido de 1024
}
```

### 2. Database (RDS)

#### Scheduled Scaling
```bash
# Parar RDS durante off-hours
aws rds stop-db-instance \
    --db-instance-identifier agrovalue-n8n-database

# Automatizar com Lambda
aws events put-rule \
    --name "StopRDSNightly" \
    --schedule-expression "cron(0 22 * * ? *)"
```

#### Snapshot Lifecycle
```hcl
# Otimizar retenção de backups
variable "backup_retention_days" {
  default = 3  # Reduzido de 7
}
```

#### Aurora Serverless (Para Cargas Esporádicas)
```hcl
resource "aws_rds_cluster" "aurora_serverless" {
  engine             = "aurora-postgresql"
  engine_mode        = "serverless"
  database_name      = var.db_name
  master_username    = var.db_username
  master_password    = var.db_password
  
  scaling_configuration {
    auto_pause   = true
    min_capacity = 2
    max_capacity = 4
    seconds_until_auto_pause = 300
  }
}
```

### 3. Networking

#### Single NAT Gateway
```hcl
# Usar apenas 1 NAT Gateway para desenvolvimento
resource "aws_nat_gateway" "main" {
  count         = 1  # Reduzido de 2
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
}
```

#### VPC Endpoints (Para Alto Tráfego S3)
```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  # Evita custos de NAT Gateway para S3
}
```

### 4. Storage

#### S3 Intelligent Tiering
```hcl
resource "aws_s3_bucket_intelligent_tiering_configuration" "n8n_data" {
  bucket = aws_s3_bucket.n8n_data.id
  name   = "EntireBucket"

  status = "Enabled"
}
```

#### Lifecycle Policies Agressivas
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "n8n_data" {
  bucket = aws_s3_bucket.n8n_data.id

  rule {
    id     = "cost_optimization"
    status = "Enabled"

    transition {
      days          = 7    # IA após 7 dias
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30   # Glacier após 30 dias
      storage_class = "GLACIER"
    }

    transition {
      days          = 90   # Deep Archive após 90 dias
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365  # Deletar após 1 ano
    }
  }
}
```

### 5. Monitoramento

#### CloudWatch Log Retention Otimizada
```hcl
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.project_name}"
  retention_in_days = 3  # Reduzido de 7
}
```

#### Métricas Customizadas Seletivas
```javascript
// Apenas métricas críticas
const metrics = [
  'CPUUtilization',
  'MemoryUtilization',
  'RequestCount'
  // Remover métricas não essenciais
];
```

## 🤖 Automação de Custos

### Script de Otimização Noturna

```bash
#!/bin/bash
# scripts/optimize-costs.sh

# Parar tarefas ECS não críticas
aws ecs update-service \
    --cluster agrovalue-n8n-cluster \
    --service agrovalue-n8n-service \
    --desired-count 0

# Parar RDS (se configurado)
if [ "$ENVIRONMENT" != "production" ]; then
    aws rds stop-db-instance \
        --db-instance-identifier agrovalue-n8n-database
fi

# Limpar logs antigos
aws logs delete-log-group \
    --log-group-name "/aws/ecs/old-logs" 2>/dev/null || true
```

### Lambda para Auto-Scaling Inteligente

```python
# lambda/cost_optimizer.py
import boto3
import json
from datetime import datetime, time

def lambda_handler(event, context):
    ecs = boto3.client('ecs')
    cloudwatch = boto3.client('cloudwatch')
    
    # Verificar CPU médio das últimas 2 horas
    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/ECS',
        MetricName='CPUUtilization',
        Dimensions=[
            {'Name': 'ServiceName', 'Value': 'agrovalue-n8n-service'},
            {'Name': 'ClusterName', 'Value': 'agrovalue-n8n-cluster'}
        ],
        StartTime=datetime.utcnow() - timedelta(hours=2),
        EndTime=datetime.utcnow(),
        Period=3600,
        Statistics=['Average']
    )
    
    avg_cpu = sum(point['Average'] for point in response['Datapoints']) / len(response['Datapoints'])
    
    # Escalar baseado na utilização
    if avg_cpu < 20:
        desired_count = 1
    elif avg_cpu < 60:
        desired_count = 2
    else:
        desired_count = 3
    
    # Atualizar serviço
    ecs.update_service(
        cluster='agrovalue-n8n-cluster',
        service='agrovalue-n8n-service',
        desiredCount=desired_count
    )
    
    return {'statusCode': 200, 'body': json.dumps(f'Scaled to {desired_count} tasks')}
```

## 📈 Monitoramento de Custos

### Alertas Proativos

```bash
# Criar alerta para $50/mês
aws cloudwatch put-metric-alarm \
    --alarm-name "N8N-Cost-Alert-50" \
    --alarm-description "Alert at $50/month" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --threshold 50 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD
```

### Dashboard de Custos Customizado

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "AmazonECS"],
          [".", ".", ".", ".", ".", "AmazonRDS"],
          [".", ".", ".", ".", ".", "AmazonEC2"]
        ],
        "period": 86400,
        "stat": "Maximum",
        "region": "us-east-1",
        "title": "Custos Diários por Serviço"
      }
    }
  ]
}
```

### Script de Relatório de Custos

```bash
#!/bin/bash
# scripts/cost-report.sh

# Gerar relatório detalhado
aws ce get-cost-and-usage \
    --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity DAILY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --output table
```

## 🎯 Metas de Otimização

### Curto Prazo (1-3 meses)
- [ ] Implementar Spot Instances (✅ Já feito)
- [ ] Configurar scheduled scaling
- [ ] Otimizar retenção de logs
- [ ] Configurar alertas de custo

### Médio Prazo (3-6 meses)
- [ ] Migrar para Aurora Serverless (se aplicável)
- [ ] Implementar VPC Endpoints
- [ ] Otimizar storage lifecycle
- [ ] Automatizar scaling inteligente

### Longo Prazo (6+ meses)
- [ ] Considerar Reserved Instances
- [ ] Implementar multi-region com failover
- [ ] Otimizar para Savings Plans
- [ ] Avaliar arquiteturas serverless

## 📊 ROI de Otimizações

### Análise de Impacto

| Otimização | Implementação | Economia Mensal | ROI |
|------------|---------------|-----------------|-----|
| Spot Instances | Baixa | $20-30 | 300% |
| Scheduled Scaling | Média | $15-25 | 200% |
| Log Optimization | Baixa | $5-10 | 500% |
| Storage Lifecycle | Baixa | $3-8 | 400% |
| Single NAT | Baixa | $10-16 | 200% |

### Ferramentas de Monitoramento

1. **AWS Cost Explorer**: Análise detalhada
2. **AWS Budgets**: Alertas proativos
3. **CloudWatch**: Métricas em tempo real
4. **Script customizado**: `scripts/monitor-costs.sh`

## 🚨 Alertas de Custo Configurados

```bash
# Executar script de monitoramento
./scripts/monitor-costs.sh

# Configurar alertas automáticos
aws budgets create-budget \
    --account-id $(aws sts get-caller-identity --query Account --output text) \
    --budget '{
        "BudgetName": "N8N-Monthly-Budget",
        "BudgetLimit": {"Amount": "100", "Unit": "USD"},
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }' \
    --notifications-with-subscribers '[{
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [{
            "SubscriptionType": "EMAIL",
            "Address": "admin@agrovalue.com"
        }]
    }]'
```

## 💡 Dicas Avançadas

### 1. Spot Fleet Diversification
```hcl
# Usar mix de tipos de instância
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight           = 80
  base             = 0
}

capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight           = 20
  base             = 1
}
```

### 2. Cross-Region Backup Otimizado
```bash
# Backup apenas essencial para outra região
aws s3 sync s3://bucket-primary s3://bucket-backup-region \
    --storage-class GLACIER \
    --exclude "*" \
    --include "*.json" \
    --include "workflows/*"
```

### 3. Caching Inteligente
```nginx
# nginx.conf - Cache estático
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

---

**🎯 Meta**: Manter custos mensais abaixo de $80 com performance adequada para workloads de produção.

**📈 Próxima Revisão**: Revisar custos mensalmente e ajustar estratégias conforme necessário.
