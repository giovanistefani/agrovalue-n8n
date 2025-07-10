# Solução de Problemas - AgroValue N8N

Este guia ajuda a resolver problemas comuns no ambiente N8N local e na AWS.

## 🐳 Problemas com Docker Local

### Container N8N não inicia

**Sintoma**: Container para logo após iniciar
```bash
docker-compose -f docker/docker-compose.yml logs n8n
```

**Possíveis Causas e Soluções**:

1. **Porta já em uso**
   ```bash
   # Verificar processo usando a porta
   sudo lsof -i :5678
   # Parar processo
   sudo kill -9 <PID>
   ```

2. **Erro de permissão**
   ```bash
   # Adicionar usuário ao grupo docker
   sudo usermod -aG docker $USER
   # Fazer logout/login
   ```

3. **Variáveis de ambiente inválidas**
   ```bash
   # Verificar arquivo .env.local
   cat configs/.env.local
   # Recriar se necessário
   cp configs/.env.example configs/.env.local
   ```

### Erro de conexão com PostgreSQL

**Sintoma**: `ECONNREFUSED 172.20.0.3:5432`

**Solução**:
```bash
# Verificar status do PostgreSQL
docker-compose -f docker/docker-compose.yml ps postgres

# Reiniciar PostgreSQL
docker-compose -f docker/docker-compose.yml restart postgres

# Verificar logs
docker-compose -f docker/docker-compose.yml logs postgres

# Testar conexão manual
docker exec -it n8n_postgres psql -U n8n -d n8n -c "SELECT version();"
```

### Volume Docker não monta

**Sintoma**: Dados não persistem entre reinicializações

**Solução**:
```bash
# Verificar volumes
docker volume ls | grep n8n

# Recriar volumes se corrompidos
docker-compose -f docker/docker-compose.yml down -v
docker volume prune -f
./scripts/start-local.sh
```

### Erro de certificado SSL

**Sintoma**: Erro SSL no navegador (desenvolvimento local)

**Solução**:
```bash
# Regenerar certificado
rm -rf configs/nginx/ssl/*
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout configs/nginx/ssl/key.pem \
    -out configs/nginx/ssl/cert.pem \
    -subj "/C=BR/ST=SP/L=Sao Paulo/O=AgroValue/CN=localhost"

# Reiniciar nginx
docker-compose -f docker/docker-compose.yml restart nginx
```

## ☁️ Problemas com AWS

### Deploy Terraform falha

**Sintoma**: `Error: UnauthorizedOperation`

**Solução**:
```bash
# Verificar credenciais
aws sts get-caller-identity

# Verificar permissões necessárias
aws iam get-user
aws iam list-attached-user-policies --user-name <seu-usuario>

# Configurar credenciais se necessário
aws configure
```

### ECS Task não inicia

**Sintoma**: Tasks ficam em estado `PENDING` ou `STOPPED`

**Diagnóstico**:
```bash
# Verificar eventos do serviço
aws ecs describe-services \
    --cluster agrovalue-n8n-cluster \
    --services agrovalue-n8n-service \
    --query "services[0].events"

# Verificar logs da task
aws logs filter-log-events \
    --log-group-name /aws/ecs/agrovalue-n8n \
    --start-time $(date -d '1 hour ago' +%s)000
```

**Soluções Comuns**:

1. **Erro de IAM**
   ```bash
   # Verificar role de execução
   aws iam get-role --role-name agrovalue-n8n-ecs-execution-role
   
   # Verificar políticas anexadas
   aws iam list-attached-role-policies \
       --role-name agrovalue-n8n-ecs-execution-role
   ```

2. **Erro de Secrets Manager**
   ```bash
   # Verificar se secrets existem
   aws secretsmanager list-secrets \
       --query "SecretList[?contains(Name, 'agrovalue-n8n')]"
   
   # Verificar valores
   aws secretsmanager get-secret-value \
       --secret-id agrovalue-n8n/n8n-auth-password
   ```

3. **Recursos insuficientes**
   ```bash
   # Aumentar recursos temporariamente
   aws ecs update-service \
       --cluster agrovalue-n8n-cluster \
       --service agrovalue-n8n-service \
       --task-definition agrovalue-n8n-task \
       --desired-count 1
   ```

### RDS não conecta

**Sintoma**: `connection refused` ou timeout

**Diagnóstico**:
```bash
# Verificar status RDS
aws rds describe-db-instances \
    --db-instance-identifier agrovalue-n8n-database \
    --query "DBInstances[0].DBInstanceStatus"

# Verificar security groups
aws ec2 describe-security-groups \
    --group-ids <sg-id> \
    --query "SecurityGroups[0].IpPermissions"
```

**Soluções**:

1. **Security Group**
   ```bash
   # Verificar regras do SG
   aws ec2 describe-security-groups \
       --filters "Name=group-name,Values=*n8n-rds*"
   
   # Adicionar regra se necessário (cuidado!)
   aws ec2 authorize-security-group-ingress \
       --group-id sg-xxx \
       --protocol tcp \
       --port 5432 \
       --source-group sg-yyy
   ```

2. **RDS parado**
   ```bash
   # Iniciar RDS
   aws rds start-db-instance \
       --db-instance-identifier agrovalue-n8n-database
   ```

### ALB retorna 502/503

**Sintoma**: Load balancer retorna erro de gateway

**Diagnóstico**:
```bash
# Verificar targets saudáveis
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...

# Verificar health check
aws elbv2 describe-target-groups \
    --target-group-arns arn:aws:elasticloadbalancing:... \
    --query "TargetGroups[0].HealthCheckPath"
```

**Soluções**:

1. **Health check falha**
   ```bash
   # Testar endpoint manualmente
   # Obter IP privado da task
   aws ecs describe-tasks \
       --cluster agrovalue-n8n-cluster \
       --tasks $(aws ecs list-tasks --cluster agrovalue-n8n-cluster --query "taskArns[0]" --output text)
   
   # Verificar se /healthz responde
   curl http://<task-private-ip>:5678/healthz
   ```

2. **Security group ECS**
   ```bash
   # Verificar se ALB pode acessar ECS
   aws ec2 describe-security-groups \
       --filters "Name=group-name,Values=*ecs-tasks*"
   ```

## 🔧 Ferramentas de Debug

### Script de Diagnóstico Completo

```bash
#!/bin/bash
# scripts/debug.sh

echo "🔍 Diagnóstico AgroValue N8N"

# Verificar ambiente local
if [ -f "docker/docker-compose.yml" ]; then
    echo "📋 Status Docker Local:"
    docker-compose -f docker/docker-compose.yml ps
    
    echo "📊 Uso de recursos:"
    docker stats --no-stream
fi

# Verificar AWS
if command -v aws &> /dev/null; then
    echo "☁️  Status AWS:"
    
    # ECS
    aws ecs describe-clusters \
        --clusters agrovalue-n8n-cluster \
        --query "clusters[0].status" 2>/dev/null || echo "  Cluster não encontrado"
    
    # RDS
    aws rds describe-db-instances \
        --db-instance-identifier agrovalue-n8n-database \
        --query "DBInstances[0].DBInstanceStatus" 2>/dev/null || echo "  RDS não encontrado"
    
    # ALB
    aws elbv2 describe-load-balancers \
        --names agrovalue-n8n-alb \
        --query "LoadBalancers[0].State.Code" 2>/dev/null || echo "  ALB não encontrado"
fi
```

### Logs Centralizados

```bash
# Todos os logs locais
docker-compose -f docker/docker-compose.yml logs --tail=100

# Logs AWS específicos
aws logs filter-log-events \
    --log-group-name /aws/ecs/agrovalue-n8n \
    --start-time $(date -d '30 minutes ago' +%s)000 \
    --filter-pattern "ERROR"
```

### Health Check Manual

```bash
# Local
curl -f http://localhost:5678/healthz

# AWS (via ALB)
curl -f https://your-domain.com/healthz
# ou
curl -f http://your-alb-dns-name/healthz
```

## 📊 Monitoramento Proativo

### Alertas CloudWatch

```bash
# Criar alerta para falhas de health check
aws cloudwatch put-metric-alarm \
    --alarm-name "N8N-HealthCheck-Failures" \
    --alarm-description "Alert on health check failures" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions Name=TargetGroup,Value=your-target-group \
    --evaluation-periods 2
```

### Script de Monitoramento

```bash
#!/bin/bash
# scripts/monitor.sh

while true; do
    # Verificar health local
    if ! curl -sf http://localhost:5678/healthz > /dev/null 2>&1; then
        echo "❌ $(date): N8N local não está respondendo"
    fi
    
    # Verificar health AWS
    if ! curl -sf http://your-alb-dns/healthz > /dev/null 2>&1; then
        echo "❌ $(date): N8N AWS não está respondendo"
    fi
    
    sleep 30
done
```

## 🆘 Recursos de Suporte

### Logs Detalhados

**Local**:
```bash
# Habilitar debug
echo "N8N_LOG_LEVEL=debug" >> configs/.env.local
docker-compose -f docker/docker-compose.yml restart n8n
```

**AWS**:
```bash
# Atualizar task definition para debug
aws ecs register-task-definition \
    --family agrovalue-n8n-task \
    --container-definitions '[{
        "name": "n8n",
        "environment": [
            {"name": "N8N_LOG_LEVEL", "value": "debug"}
        ]
    }]'
```

### Backup de Emergência

```bash
# Backup rápido antes de mudanças
./scripts/backup.sh --local-only --verify

# Backup AWS crítico
aws rds create-db-snapshot \
    --db-instance-identifier agrovalue-n8n-database \
    --db-snapshot-identifier emergency-backup-$(date +%Y%m%d-%H%M%S)
```

### Rollback Rápido

```bash
# Voltar versão anterior Docker
docker-compose -f docker/docker-compose.yml down
git checkout HEAD~1 -- docker/
docker-compose -f docker/docker-compose.yml up -d

# Rollback Terraform
cd terraform
terraform plan -destroy -target=aws_ecs_service.n8n
terraform apply -target=aws_ecs_service.n8n
```

## 📞 Checklist de Emergência

### Quando o N8N para de funcionar:

1. ✅ Verificar logs: `docker-compose logs` ou CloudWatch
2. ✅ Verificar recursos: CPU, memória, disk
3. ✅ Verificar conectividade: rede, database
4. ✅ Verificar certificados: SSL, credenciais
5. ✅ Verificar dependências: PostgreSQL, Redis
6. ✅ Fazer backup: antes de mudanças
7. ✅ Aplicar fix: mudança mínima necessária
8. ✅ Verificar health: endpoints funcionando
9. ✅ Monitorar: por pelo menos 15 minutos
10. ✅ Documentar: o que causou e como foi resolvido

### Contatos de Emergência

- **AWS Support**: https://console.aws.amazon.com/support/
- **N8N Community**: https://community.n8n.io/
- **Docker Support**: https://docs.docker.com/
- **Terraform Issues**: https://github.com/hashicorp/terraform/issues

---

**🔧 Dica**: Mantenha sempre um backup recente e teste os procedimentos de recovery regularmente.
