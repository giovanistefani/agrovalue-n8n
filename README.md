# AgroValue N8N

Este repositório contém a configuração para a instância do n8n da AgroValue, preparada para rodar tanto em ambiente de desenvolvimento local quanto em produção na AWS.

## Visão Geral

O [n8n](https://n8n.io/) é uma ferramenta de automação de fluxo de trabalho de código aberto. Esta configuração utiliza Docker e Docker Compose para facilitar o deploy e garantir a consistência entre os ambientes.

- **Desenvolvimento Local**: Usa o banco de dados SQLite padrão do n8n para simplicidade e rapidez.
- **Produção (AWS)**: Projetado para usar um banco de dados PostgreSQL para maior robustez e escalabilidade.

## Pré-requisitos

Certifique-se de ter as seguintes ferramentas instaladas em sua máquina:

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Configuração para Desenvolvimento Local

Siga os passos abaixo para executar o n8n em sua máquina local.

### 1. Clone o Repositório

```bash
git clone <URL_DO_SEU_REPOSITORIO>
cd agrovalue-n8n
```

### 2. Crie o Arquivo de Ambiente

Copie o arquivo de exemplo `.env.example` para um novo arquivo chamado `.env`.

```bash
cp .env.example .env
```

O arquivo `.env` já vem pré-configurado para o ambiente de desenvolvimento. Você não precisa alterá-lo para começar.

### 3. Inicie os Contêineres

Use o Docker Compose para construir e iniciar o serviço do n8n.

```bash
docker-compose up -d
```

O `-d` executa os contêineres em modo "detached" (em segundo plano).

### 4. Acesse o n8n

Após a inicialização, o n8n estará disponível no seu navegador em:
**http://localhost:5678**

Os dados dos seus workflows e credenciais serão salvos no diretório `n8n_data`, que é ignorado pelo Git.

## Estrutura do Projeto

```
├── .gitignore          # Arquivos e diretórios a serem ignorados pelo Git
├── docker-compose.yml  # Define os serviços, redes e volumes do Docker
├── .env.example        # Arquivo de exemplo para as variáveis de ambiente
├── n8n_data/           # (Criado após a 1ª execução) Armazena dados do n8n localmente
└── README.md           # Este arquivo
```

## Configuração para Produção (AWS)

Para implantar em produção na AWS, a abordagem recomendada é usar uma instância EC2 com Docker, conectada a um serviço de banco de dados como o AWS RDS (PostgreSQL).

1.  **Infraestrutura AWS**:
    *   Provisione uma instância EC2 (ex: `t3.small` ou superior).
    *   Provisione um banco de dados PostgreSQL no AWS RDS.
    *   Configure um Security Group para permitir tráfego na porta `80/443` (para acesso web) e `5432` (do EC2 para o RDS).

2.  **Configuração do Servidor**:
    *   Instale Docker e Docker Compose na instância EC2.
    *   Clone este repositório.

3.  **Configuração do `.env` de Produção**:
    *   Crie um arquivo `.env` no servidor. **NÃO** comite este arquivo no Git.
    *   Descomente e preencha as variáveis de banco de dados (`DB_TYPE`, `DB_POSTGRESDB_*`) com as credenciais do seu RDS.
    *   Altere `N8N_HOST` para `0.0.0.0`.
    *   Defina o `WEBHOOK_URL` para o seu domínio público (ex: `https://n8n.agrovalue.com.br`).

4.  **Ative o Serviço de Banco de Dados**:
    *   No arquivo `docker-compose.yml`, descomente a seção do serviço `db` se você optar por rodar o PostgreSQL no mesmo host (não recomendado para produção em larga escala, prefira o RDS).

5.  **Reverse Proxy (Obrigatório para HTTPS)**:
    *   Configure um reverse proxy como Nginx ou Caddy na instância EC2 para gerenciar o tráfego de entrada, apontar para o contêiner do n8n (`http://localhost:5678`) e, crucialmente, para configurar o SSL/TLS (HTTPS).

6.  **Deploy**:
    *   Execute `docker-compose up -d` no servidor.

## Comandos Úteis do Docker Compose

- **Parar os serviços**: `docker-compose down`
- **Ver os logs**: `docker-compose logs -f n8n`
- **Reiniciar os serviços**: `docker-compose restart`