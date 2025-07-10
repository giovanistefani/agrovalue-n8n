#!/bin/bash

# Script para parar o ambiente local
set -e

echo "🛑 Parando AgroValue N8N - Ambiente Local"

# Parar e remover containers
docker-compose -f docker/docker-compose.yml down

echo "✅ Containers parados com sucesso!"
echo ""
echo "💾 Para remover volumes (dados persistentes), execute:"
echo "   docker-compose -f docker/docker-compose.yml down -v"
echo ""
echo "🧹 Para limpar imagens não utilizadas, execute:"
echo "   docker system prune"
