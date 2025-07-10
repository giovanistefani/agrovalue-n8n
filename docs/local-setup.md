# Configuração Local - AgroValue N8N

Este guia mostra como configurar e executar o n8n localmente para desenvolvimento.

## Pré-requisitos

### Software Necessário

1. **Docker & Docker Compose**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install docker.io docker-compose
   
   # CentOS/RHEL
   sudo yum install docker docker-compose
   
   # macOS (com Homebrew)
   brew install docker docker-compose
   ```

2. **Git**
   ```bash
   # Ubuntu/Debian
   sudo apt install git
   
   # CentOS/RHEL
   sudo yum install git
   
   # macOS
   brew install git
   ```

3. **OpenSSL** (para certificados SSL locais)
   ```bash
   # Ubuntu/Debian
   sudo apt install openssl
   
   # CentOS/RHEL
   sudo yum install openssl
   
   # macOS (já incluído)
   ```

## Configuração Inicial

### 1. Clonar o Repositório

```bash
git clone <repository-url>
cd agrovalue-n8n
```

### 2. Configurar Variáveis de Ambiente

```bash
# Copiar arquivo de exemplo
cp configs/.env.example configs/.env.local

# Editar configurações
nano configs/.env.local
```

**Variáveis importantes para configurar:**

```bash
# Autenticação N8N
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=sua_senha_segura

# Chave de criptografia (32 caracteres)
N8N_ENCRYPTION_KEY=sua_chave_de_criptografia_32_chars

# Banco de dados
POSTGRES_PASSWORD=senha_postgres_segura

# Timezone
TIMEZONE=America/Sao_Paulo
```

### 3. Iniciar Ambiente Local

```bash
# Tornar script executável
chmod +x scripts/start-local.sh

# Iniciar serviços
./scripts/start-local.sh
```

O script irá:
- ✅ Verificar dependências
- 📄 Criar arquivo de configuração se não existir
- 🔐 Gerar certificado SSL self-signed
- 🐳 Construir e iniciar containers
- ⏳ Aguardar serviços ficarem prontos

## Acessando os Serviços

### N8N Web Interface
- **URL**: http://localhost:5678
- **Usuário**: admin (ou conforme configurado)
- **Senha**: Conforme configurado em `N8N_BASIC_AUTH_PASSWORD`

### PostgreSQL
- **Host**: localhost
- **Porta**: 5432
- **Database**: n8n
- **Usuário**: n8n
- **Senha**: Conforme configurado

### Redis
- **Host**: localhost
- **Porta**: 6379

## Estrutura de Diretórios

```
docker/
├── docker-compose.yml    # Configuração principal
├── Dockerfile           # Imagem customizada do n8n
└── .dockerignore       # Arquivos ignorados

configs/
├── .env.example        # Exemplo de configuração
├── .env.local         # Configuração local (criado automaticamente)
├── nginx/
│   └── nginx.conf     # Configuração do proxy
└── local/             # Configurações específicas locais

workflows/              # Workflows de exemplo
logs/                  # Logs locais
```

## Comandos Úteis

### Visualizar Logs
```bash
# Todos os serviços
docker-compose -f docker/docker-compose.yml logs -f

# Apenas N8N
docker-compose -f docker/docker-compose.yml logs -f n8n

# Apenas PostgreSQL
docker-compose -f docker/docker-compose.yml logs -f postgres
```

### Parar Serviços
```bash
# Parar containers
./scripts/stop-local.sh

# Parar e remover volumes (remove dados)
docker-compose -f docker/docker-compose.yml down -v
```

### Reiniciar Serviços
```bash
# Reiniciar um serviço específico
docker-compose -f docker/docker-compose.yml restart n8n

# Reconstruir imagens
docker-compose -f docker/docker-compose.yml up -d --build
```

### Backup Local
```bash
# Backup do banco de dados
docker exec n8n_postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup dos workflows (se salvos em arquivos)
cp -r workflows/ backup_workflows_$(date +%Y%m%d_%H%M%S)/
```

## Desenvolvimento

### Adicionando Custom Nodes

1. Criar diretório para nodes customizados:
   ```bash
   mkdir -p docker/custom-nodes
   ```

2. Adicionar seus nodes no diretório

3. Reconstruir a imagem:
   ```bash
   docker-compose -f docker/docker-compose.yml up -d --build
   ```

### Configurações Avançadas

#### Habilitar HTTPS Local

O script já gera certificados self-signed. Para usar um certificado específico:

1. Coloque seus certificados em `configs/nginx/ssl/`
2. Edite `configs/nginx/nginx.conf` para usar HTTPS
3. Reinicie o nginx:
   ```bash
   docker-compose -f docker/docker-compose.yml restart nginx
   ```

#### Configurar Email (SMTP)

Edite o arquivo `.env.local`:

```bash
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=seu_email@gmail.com
N8N_SMTP_PASS=sua_senha_de_app
N8N_SMTP_SENDER=seu_email@gmail.com
```

## Solução de Problemas

### Erro de Permissão do Docker

```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER

# Fazer logout e login novamente
```

### Porta Já em Uso

```bash
# Verificar quais portas estão sendo usadas
sudo netstat -tulpn | grep :5678

# Parar processo usando a porta
sudo kill -9 <PID>
```

### Container Não Inicia

```bash
# Verificar logs detalhados
docker-compose -f docker/docker-compose.yml logs n8n

# Verificar recursos disponíveis
docker system df
docker system prune
```

### Erro de Conexão com Banco

1. Verificar se PostgreSQL está rodando:
   ```bash
   docker-compose -f docker/docker-compose.yml ps postgres
   ```

2. Verificar logs do PostgreSQL:
   ```bash
   docker-compose -f docker/docker-compose.yml logs postgres
   ```

3. Testar conexão manualmente:
   ```bash
   docker exec -it n8n_postgres psql -U n8n -d n8n
   ```

## Performance Local

### Otimização de Recursos

Para máquinas com recursos limitados, edite `docker/docker-compose.yml`:

```yaml
n8n:
  # Adicionar limites de recursos
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 512M
      reservations:
        cpus: '0.25'
        memory: 256M
```

### Monitoramento

```bash
# Uso de recursos dos containers
docker stats

# Espaço em disco
docker system df
```

## Próximos Passos

1. Acesse http://localhost:5678 e configure seu primeiro workflow
2. Importe workflows de exemplo da pasta `workflows/`
3. Configure credenciais para serviços externos
4. Teste webhooks usando ngrok ou similar para desenvolvimento
5. Quando pronto, faça deploy na AWS usando `./scripts/deploy-aws.sh`

---

**💡 Dica**: Mantenha o ambiente local sempre atualizado executando `./scripts/start-local.sh` periodicamente para obter as últimas versões das imagens Docker.
