#!/bin/bash

# Script para backup do ambiente N8N
set -e

echo "💾 AgroValue N8N - Backup Completo"

# Configurações
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
S3_BUCKET="${S3_BACKUP_BUCKET:-agrovalue-n8n-backups}"

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

echo "📁 Criando backup em: $BACKUP_DIR"

# Função para backup local
backup_local() {
    echo "🏠 Fazendo backup do ambiente local..."
    
    if [ -f "docker/docker-compose.yml" ]; then
        # Backup do banco PostgreSQL local
        echo "  📊 Backup do banco de dados..."
        docker exec n8n_postgres pg_dump -U n8n n8n > "$BACKUP_DIR/database_local.sql" 2>/dev/null || echo "  ⚠️  Banco local não disponível"
        
        # Backup dos workflows (se houver)
        if [ -d "workflows" ]; then
            echo "  🔄 Backup dos workflows..."
            cp -r workflows "$BACKUP_DIR/workflows_local"
        fi
        
        # Backup das configurações
        echo "  ⚙️  Backup das configurações..."
        cp -r configs "$BACKUP_DIR/configs" 2>/dev/null || true
        
        # Backup dos volumes Docker (dados do n8n)
        echo "  🐳 Backup dos volumes Docker..."
        docker run --rm \
            -v n8n_data:/data \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine tar czf /backup/n8n_data.tar.gz -C /data . 2>/dev/null || echo "  ⚠️  Volume n8n_data não encontrado"
    else
        echo "  ❌ Ambiente local não configurado"
    fi
}

# Função para backup AWS
backup_aws() {
    echo "☁️  Fazendo backup do ambiente AWS..."
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        echo "  ❌ AWS CLI não disponível"
        return 1
    fi
    
    # Verificar credenciais
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "  ❌ Credenciais AWS não configuradas"
        return 1
    fi
    
    # Backup RDS
    echo "  📊 Criando snapshot RDS..."
    SNAPSHOT_ID="agrovalue-n8n-backup-$(date +%Y%m%d-%H%M%S)"
    aws rds create-db-snapshot \
        --db-instance-identifier agrovalue-n8n-database \
        --db-snapshot-identifier "$SNAPSHOT_ID" \
        --region ${AWS_REGION:-us-east-1} 2>/dev/null && echo "  ✅ Snapshot criado: $SNAPSHOT_ID" || echo "  ⚠️  Erro ao criar snapshot RDS"
    
    # Backup S3 (sincronizar bucket)
    echo "  🗃️  Backup dos dados S3..."
    if aws s3 ls "s3://$S3_BUCKET" &>/dev/null; then
        aws s3 sync "s3://$(aws s3 ls | grep agrovalue-n8n-data | awk '{print $3}' | head -1)" "$BACKUP_DIR/s3_data/" 2>/dev/null || echo "  ⚠️  Bucket S3 não encontrado"
    fi
    
    # Backup da configuração Terraform
    echo "  🏗️  Backup da infraestrutura..."
    if [ -d "terraform" ]; then
        cp -r terraform "$BACKUP_DIR/terraform"
        
        # Salvar state do Terraform (se existir)
        if [ -f "terraform/terraform.tfstate" ]; then
            cp terraform/terraform.tfstate "$BACKUP_DIR/terraform.tfstate"
        fi
        
        # Exportar outputs do Terraform
        cd terraform 2>/dev/null && terraform output -json > "../$BACKUP_DIR/terraform_outputs.json" 2>/dev/null || echo "  ⚠️  Não foi possível exportar outputs"
        cd .. 2>/dev/null || true
    fi
    
    # Backup das métricas CloudWatch (últimos 7 dias)
    echo "  📊 Backup das métricas CloudWatch..."
    aws logs describe-log-groups \
        --log-group-name-prefix "/aws/ecs/agrovalue-n8n" \
        --region ${AWS_REGION:-us-east-1} > "$BACKUP_DIR/cloudwatch_loggroups.json" 2>/dev/null || true
    
    # Listar recursos AWS criados
    echo "  📋 Inventário de recursos AWS..."
    {
        echo "=== VPCs ==="
        aws ec2 describe-vpcs --filters "Name=tag:Project,Values=AgroValue-N8N" --region ${AWS_REGION:-us-east-1} 2>/dev/null || true
        echo ""
        echo "=== ECS Clusters ==="
        aws ecs list-clusters --region ${AWS_REGION:-us-east-1} 2>/dev/null || true
        echo ""
        echo "=== RDS Instances ==="
        aws rds describe-db-instances --region ${AWS_REGION:-us-east-1} 2>/dev/null || true
        echo ""
        echo "=== Load Balancers ==="
        aws elbv2 describe-load-balancers --region ${AWS_REGION:-us-east-1} 2>/dev/null || true
    } > "$BACKUP_DIR/aws_resources.txt"
}

# Função para compactar backup
compress_backup() {
    echo "🗜️  Compactando backup..."
    
    cd "$(dirname "$BACKUP_DIR")"
    tar -czf "$(basename "$BACKUP_DIR").tar.gz" "$(basename "$BACKUP_DIR")"
    
    # Remover diretório não compactado
    rm -rf "$(basename "$BACKUP_DIR")"
    
    echo "✅ Backup compactado: $(basename "$BACKUP_DIR").tar.gz"
    echo "📁 Tamanho: $(du -h "$(basename "$BACKUP_DIR").tar.gz" | cut -f1)"
}

# Função para upload para S3 (opcional)
upload_to_s3() {
    if [ "$1" = "--upload" ]; then
        echo "☁️  Fazendo upload do backup para S3..."
        
        # Criar bucket se não existir
        aws s3 mb "s3://$S3_BUCKET" 2>/dev/null || true
        
        # Upload do backup
        BACKUP_FILE="$(basename "$BACKUP_DIR").tar.gz"
        aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/backups/" && echo "✅ Upload concluído" || echo "❌ Erro no upload"
        
        # Configurar lifecycle para limpar backups antigos
        aws s3api put-bucket-lifecycle-configuration \
            --bucket "$S3_BUCKET" \
            --lifecycle-configuration '{
                "Rules": [{
                    "ID": "DeleteOldBackups",
                    "Status": "Enabled",
                    "Filter": {"Prefix": "backups/"},
                    "Expiration": {"Days": 30}
                }]
            }' 2>/dev/null || true
    fi
}

# Função para verificar integridade
verify_backup() {
    echo "🔍 Verificando integridade do backup..."
    
    BACKUP_FILE="$(basename "$BACKUP_DIR").tar.gz"
    
    if [ -f "$BACKUP_FILE" ]; then
        if tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
            echo "✅ Backup válido e íntegro"
        else
            echo "❌ Backup corrompido!"
            return 1
        fi
    else
        echo "❌ Arquivo de backup não encontrado"
        return 1
    fi
}

# Função para limpar backups antigos
cleanup_old_backups() {
    echo "🧹 Limpando backups antigos (>30 dias)..."
    
    find backups -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    
    local removed=$(find backups -name "*.tar.gz" -mtime +30 2>/dev/null | wc -l)
    echo "🗑️  $removed backups antigos removidos"
}

# Menu de ajuda
show_help() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Opções:"
    echo "  --local-only    Fazer backup apenas do ambiente local"
    echo "  --aws-only      Fazer backup apenas do ambiente AWS"
    echo "  --upload        Fazer upload do backup para S3"
    echo "  --verify        Verificar integridade após backup"
    echo "  --cleanup       Limpar backups antigos"
    echo "  --help          Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                    # Backup completo (local + AWS)"
    echo "  $0 --local-only       # Apenas ambiente local"
    echo "  $0 --upload --verify  # Backup com upload e verificação"
}

# Processar argumentos
LOCAL_ONLY=false
AWS_ONLY=false
UPLOAD=false
VERIFY=false
CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --aws-only)
            AWS_ONLY=true
            shift
            ;;
        --upload)
            UPLOAD=true
            shift
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Executar backup
echo "🚀 Iniciando processo de backup..."
echo "⏰ $(date)"
echo ""

# Criar diretório de backups se não existir
mkdir -p backups

# Executar backups conforme solicitado
if [ "$LOCAL_ONLY" = true ]; then
    backup_local
elif [ "$AWS_ONLY" = true ]; then
    backup_aws
else
    backup_local
    backup_aws
fi

# Compactar
compress_backup

# Verificar integridade
if [ "$VERIFY" = true ]; then
    verify_backup
fi

# Upload para S3
if [ "$UPLOAD" = true ]; then
    upload_to_s3 --upload
fi

# Limpeza
if [ "$CLEANUP" = true ]; then
    cleanup_old_backups
fi

echo ""
echo "🎉 Backup concluído com sucesso!"
echo "📂 Localização: $(pwd)/$(basename "$BACKUP_DIR").tar.gz"
echo ""
echo "📝 Para restaurar:"
echo "   tar -xzf $(basename "$BACKUP_DIR").tar.gz"
echo "   # Seguir instruções de restore na documentação"
