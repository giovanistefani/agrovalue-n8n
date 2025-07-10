#!/bin/bash

# Script para deploy na AWS
set -e

echo "🚀 Deploy AgroValue N8N na AWS"

# Verificar pré-requisitos
check_prerequisites() {
    echo "🔍 Verificando pré-requisitos..."
    
    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform não está instalado. Instale em: https://terraform.io"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI não está instalado. Instale em: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ Credenciais AWS não configuradas. Execute: aws configure"
        exit 1
    fi
    
    echo "✅ Pré-requisitos verificados"
}

# Configurar variáveis de ambiente
setup_environment() {
    echo "📄 Configurando ambiente..."
    
    if [ ! -f "configs/.env.production" ]; then
        echo "❌ Arquivo configs/.env.production não encontrado"
        echo "   Copie configs/.env.example para configs/.env.production e configure as variáveis"
        exit 1
    fi
    
    # Carregar variáveis de ambiente
    export $(cat configs/.env.production | grep -v '#' | xargs)
    
    echo "✅ Variáveis de ambiente carregadas"
}

# Validar configurações obrigatórias
validate_config() {
    echo "🔍 Validando configurações..."
    
    required_vars=(
        "N8N_BASIC_AUTH_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "DB_POSTGRESDB_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "❌ Variável obrigatória $var não está definida"
            exit 1
        fi
    done
    
    # Verificar se as senhas são seguras
    if [ ${#N8N_BASIC_AUTH_PASSWORD} -lt 8 ]; then
        echo "❌ N8N_BASIC_AUTH_PASSWORD deve ter pelo menos 8 caracteres"
        exit 1
    fi
    
    if [ ${#N8N_ENCRYPTION_KEY} -lt 32 ]; then
        echo "❌ N8N_ENCRYPTION_KEY deve ter pelo menos 32 caracteres"
        exit 1
    fi
    
    echo "✅ Configurações validadas"
}

# Inicializar Terraform
init_terraform() {
    echo "🏗️  Inicializando Terraform..."
    
    cd terraform
    
    terraform init
    
    echo "✅ Terraform inicializado"
}

# Planejar deploy
plan_terraform() {
    echo "📋 Planejando deploy..."
    
    terraform plan \
        -var="n8n_basic_auth_user=${N8N_BASIC_AUTH_USER:-admin}" \
        -var="n8n_basic_auth_password=${N8N_BASIC_AUTH_PASSWORD}" \
        -var="n8n_encryption_key=${N8N_ENCRYPTION_KEY}" \
        -var="db_password=${DB_POSTGRESDB_PASSWORD}" \
        -var="domain_name=${N8N_HOST:-}" \
        -var="certificate_arn=${SSL_CERTIFICATE_ARN:-}" \
        -var="aws_region=${AWS_REGION:-us-east-1}" \
        -var="environment=production" \
        -out=tfplan
    
    echo "✅ Plano criado"
}

# Executar deploy
apply_terraform() {
    echo "🚀 Executando deploy..."
    
    read -p "Deseja continuar com o deploy? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deploy cancelado"
        exit 1
    fi
    
    terraform apply tfplan
    
    echo "✅ Deploy concluído"
}

# Obter outputs importantes
get_outputs() {
    echo "📊 Obtendo informações do deploy..."
    
    echo ""
    echo "🌐 URL da aplicação:"
    terraform output -raw load_balancer_url
    echo ""
    echo ""
    echo "📋 Informações importantes:"
    echo "   - Cluster ECS: $(terraform output -raw ecs_cluster_name)"
    echo "   - Service ECS: $(terraform output -raw ecs_service_name)"
    echo "   - Bucket S3: $(terraform output -raw s3_bucket_name)"
    echo "   - Log Group: $(terraform output -raw cloudwatch_log_group)"
    echo ""
    echo "💰 Estimativa de custos:"
    terraform output -json estimated_monthly_cost | jq -r 'to_entries[] | "   - \(.key): \(.value)"'
    echo ""
    echo "💡 Dicas de otimização:"
    terraform output -json cost_optimization_tips | jq -r '.[] | "   - \(.)"'
}

# Configurar monitoramento
setup_monitoring() {
    echo "📊 Configurando monitoramento..."
    
    # Criar dashboard CloudWatch
    aws cloudwatch put-dashboard \
        --dashboard-name "AgroValue-N8N" \
        --dashboard-body file://$(pwd)/../configs/cloudwatch-dashboard.json \
        --region ${AWS_REGION:-us-east-1} || echo "⚠️  Dashboard não pôde ser criado (arquivo não encontrado)"
    
    echo "✅ Monitoramento configurado"
}

# Menu principal
main() {
    echo "🌱 AgroValue N8N - Deploy AWS"
    echo "================================"
    echo ""
    
    check_prerequisites
    setup_environment
    validate_config
    init_terraform
    plan_terraform
    apply_terraform
    get_outputs
    setup_monitoring
    
    echo ""
    echo "🎉 Deploy concluído com sucesso!"
    echo ""
    echo "📝 Próximos passos:"
    echo "   1. Acesse a URL fornecida acima"
    echo "   2. Configure seus workflows no N8N"
    echo "   3. Configure alertas SNS se necessário"
    echo "   4. Monitore custos no AWS Cost Explorer"
    echo ""
    echo "🆘 Para suporte, consulte a documentação em docs/"
}

# Tratar interrupções
trap 'echo "❌ Deploy interrompido"; exit 1' INT TERM

# Verificar se está sendo executado do diretório correto
if [ ! -f "terraform/main.tf" ]; then
    echo "❌ Execute este script a partir do diretório raiz do projeto"
    exit 1
fi

# Executar função principal
main "$@"
