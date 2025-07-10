#!/bin/bash

# Script para monitoramento de custos AWS
set -e

echo "💰 AgroValue N8N - Monitoramento de Custos AWS"

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não está instalado"
    exit 1
fi

# Verificar credenciais
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS não configuradas"
    exit 1
fi

# Obter informações da conta
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}

echo "📊 Analisando custos para conta: $ACCOUNT_ID"
echo "🌎 Região: $REGION"
echo ""

# Função para obter custos
get_costs() {
    local service=$1
    local period=${2:-"MONTHLY"}
    
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity $period \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --query "ResultsByTime[*].Groups[?Keys[0]=='$service'].Metrics.BlendedCost.Amount" \
        --output text 2>/dev/null | head -1
}

# Função para obter custo total
get_total_cost() {
    aws ce get-cost-and-usage \
        --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --query "ResultsByTime[*].Total.BlendedCost.Amount" \
        --output text 2>/dev/null | head -1
}

# Custos por serviço
echo "📋 Custos dos últimos 30 dias por serviço:"
echo "=========================================="

services=(
    "Amazon Elastic Container Service"
    "Amazon Relational Database Service"
    "Amazon Elastic Load Balancing"
    "Amazon Virtual Private Cloud"
    "Amazon Simple Storage Service"
    "Amazon CloudWatch"
    "AWS Secrets Manager"
)

total_project_cost=0

for service in "${services[@]}"; do
    cost=$(get_costs "$service")
    if [ ! -z "$cost" ] && [ "$cost" != "None" ] && [ "$cost" != "0" ]; then
        printf "%-40s $%6.2f\n" "$service:" "$cost"
        total_project_cost=$(echo "$total_project_cost + $cost" | bc -l)
    fi
done

echo "=========================================="
printf "%-40s $%6.2f\n" "Total estimado do projeto:" "$total_project_cost"

# Custo total da conta
total_account_cost=$(get_total_cost)
if [ ! -z "$total_account_cost" ] && [ "$total_account_cost" != "None" ]; then
    echo ""
    printf "%-40s $%6.2f\n" "Total da conta AWS:" "$total_account_cost"
fi

echo ""

# Verificar alertas de billing
echo "🚨 Verificando alertas de billing..."
billing_alarms=$(aws cloudwatch describe-alarms \
    --alarm-names "billing-alarm-n8n" \
    --query "MetricAlarms[0].StateValue" \
    --output text 2>/dev/null || echo "NONE")

if [ "$billing_alarms" != "NONE" ]; then
    echo "   Status do alarme: $billing_alarms"
else
    echo "   Nenhum alarme de billing configurado"
fi

# Recomendações de otimização
echo ""
echo "💡 Recomendações de Otimização:"
echo "==============================="

# Verificar instâncias ECS
ecs_tasks=$(aws ecs list-tasks \
    --cluster agrovalue-n8n-cluster \
    --query "length(taskArns)" \
    --output text 2>/dev/null || echo "0")

if [ "$ecs_tasks" -gt 2 ]; then
    echo "⚠️  Muitas tasks ECS rodando ($ecs_tasks). Considere ajustar auto-scaling."
fi

# Verificar snapshots RDS antigos
old_snapshots=$(aws rds describe-db-snapshots \
    --snapshot-type automated \
    --query "length(DBSnapshots[?SnapshotCreateTime<'$(date -d '30 days ago' --iso-8601)'])" \
    --output text 2>/dev/null || echo "0")

if [ "$old_snapshots" -gt 0 ]; then
    echo "⚠️  $old_snapshots snapshots RDS antigos. Configure retenção adequada."
fi

# Verificar volumes EBS órfãos
orphaned_volumes=$(aws ec2 describe-volumes \
    --filters Name=status,Values=available \
    --query "length(Volumes)" \
    --output text 2>/dev/null || echo "0")

if [ "$orphaned_volumes" -gt 0 ]; then
    echo "⚠️  $orphaned_volumes volumes EBS órfãos encontrados."
fi

# Sugestões gerais
echo "✅ Use instâncias Spot quando possível (já habilitado)"
echo "✅ Configure scheduled scaling para reduzir custos off-hours"
echo "✅ Monitore transfer de dados para evitar custos inesperados"
echo "✅ Considere Reserved Instances para cargas previsíveis"

# Criar alarme de billing se não existir
echo ""
echo "🔔 Configurando alarme de custos..."

# Verificar se tópico SNS existe
sns_topic="arn:aws:sns:us-east-1:$ACCOUNT_ID:billing-alerts"
if ! aws sns get-topic-attributes --topic-arn "$sns_topic" &>/dev/null; then
    echo "   Criando tópico SNS para alertas..."
    aws sns create-topic --name billing-alerts --region us-east-1 >/dev/null
fi

# Criar alarme se não existir
if ! aws cloudwatch describe-alarms --alarm-names "N8N-Cost-Alert" --region us-east-1 | grep -q "N8N-Cost-Alert"; then
    echo "   Criando alarme de custo..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "N8N-Cost-Alert" \
        --alarm-description "Alert when N8N costs exceed $100/month" \
        --metric-name EstimatedCharges \
        --namespace AWS/Billing \
        --statistic Maximum \
        --period 86400 \
        --threshold 100 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 1 \
        --alarm-actions "$sns_topic" \
        --dimensions Name=Currency,Value=USD \
        --region us-east-1 >/dev/null
    echo "   ✅ Alarme configurado para $100/mês"
fi

echo ""
echo "📊 Relatório de custos gerado com sucesso!"
echo "💾 Para histórico detalhado, acesse: https://console.aws.amazon.com/billing/"
