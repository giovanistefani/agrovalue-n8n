#!/bin/bash

# Script para iniciar o ambiente local de desenvolvimento
set -e

echo "🚀 Iniciando AgroValue N8N - Ambiente Local"

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado. Por favor, instale o Docker primeiro."
    exit 1
fi

# Verificar se Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose não está instalado. Por favor, instale o Docker Compose primeiro."
    exit 1
fi

# Criar arquivo .env local se não existir
if [ ! -f "configs/.env.local" ]; then
    echo "📄 Criando arquivo de configuração local..."
    cp configs/.env.example configs/.env.local
    echo "✅ Arquivo configs/.env.local criado. Configure suas variáveis de ambiente."
fi

# Carregar variáveis de ambiente
if [ -f "configs/.env.local" ]; then
    export $(cat configs/.env.local | grep -v '#' | xargs)
fi

# Criar diretórios necessários
echo "📁 Criando diretórios necessários..."
mkdir -p workflows
mkdir -p configs/local
mkdir -p configs/nginx/ssl
mkdir -p logs

# Gerar certificado SSL self-signed para desenvolvimento local
if [ ! -f "configs/nginx/ssl/cert.pem" ]; then
    echo "🔐 Gerando certificado SSL para desenvolvimento local..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout configs/nginx/ssl/key.pem \
        -out configs/nginx/ssl/cert.pem \
        -subj "/C=BR/ST=SP/L=Sao Paulo/O=AgroValue/CN=localhost"
fi

# Parar containers existentes
echo "🛑 Parando containers existentes..."
docker-compose -f docker/docker-compose.yml down

# Construir e iniciar containers
echo "🔨 Construindo e iniciando containers..."
docker-compose -f docker/docker-compose.yml up -d --build

# Aguardar serviços ficarem prontos
echo "⏳ Aguardando serviços ficarem prontos..."
sleep 10

# Verificar status dos serviços
echo "🔍 Verificando status dos serviços..."
docker-compose -f docker/docker-compose.yml ps

# Aguardar n8n ficar disponível
echo "⏳ Aguardando n8n ficar disponível..."
timeout 120 bash -c 'until curl -s http://localhost:5678/healthz > /dev/null; do sleep 2; done'

echo ""
echo "✅ AgroValue N8N está rodando!"
echo ""
echo "🌐 Acesse o n8n em: http://localhost:5678"
echo "👤 Usuário: ${N8N_BASIC_AUTH_USER:-admin}"
echo "🔑 Senha: ${N8N_BASIC_AUTH_PASSWORD:-admin123}"
echo ""
echo "📊 PostgreSQL está disponível em: localhost:5432"
echo "🗃️  Redis está disponível em: localhost:6379"
echo ""
echo "📋 Para ver os logs, execute:"
echo "   docker-compose -f docker/docker-compose.yml logs -f"
echo ""
echo "🛑 Para parar os serviços, execute:"
echo "   ./scripts/stop-local.sh"
