# AgroValue N8N - Automação Econômica e Escalável

## 📋 Descrição

Este projeto fornece uma configuração completa para executar o n8n (plataforma de automação de workflows) tanto localmente quanto na AWS de forma econômica e escalável. O projeto inclui configurações Docker, infraestrutura como código com Terraform, e scripts de automação.

## 🚀 Características

- **Desenvolvimento Local**: Docker Compose para desenvolvimento rápido
- **Produção AWS**: Configuração otimizada com ECS Fargate e RDS
- **Escalabilidade**: Auto-scaling baseado em métricas
- **Economia**: Instâncias Spot, backup automatizado, e recursos otimizados
- **Segurança**: VPC, subnets privadas, e configurações de segurança

## 📁 Estrutura do Projeto

```
├── docker/                 # Configurações Docker
├── terraform/             # Infraestrutura AWS (IaC)
├── scripts/               # Scripts de automação e deploy
├── workflows/             # Workflows n8n de exemplo
├── configs/               # Configurações específicas
└── docs/                  # Documentação detalhada
```

## 🛠️ Configuração Local

### Pré-requisitos

- Docker e Docker Compose
- Node.js 18+ (opcional para desenvolvimento)
- AWS CLI configurado (para deploy)
- Terraform (para infraestrutura)

### Executar Localmente

```bash
# Clonar o repositório
git clone <repository-url>
cd agrovalue-n8n

# Executar com Docker Compose
./scripts/start-local.sh

# Acessar n8n
open http://localhost:5678
```

## ☁️ Deploy na AWS

### Configuração Inicial

```bash
# Configurar variáveis de ambiente
cp configs/.env.example configs/.env.production
# Editar configs/.env.production com suas configurações

# Deploy da infraestrutura
./scripts/deploy-aws.sh
```

### Arquitetura AWS

- **ECS Fargate**: Para executar containers n8n de forma serverless
- **RDS PostgreSQL**: Banco de dados gerenciado e otimizado
- **Application Load Balancer**: Distribuição de carga e SSL
- **CloudWatch**: Monitoramento e logs
- **Auto Scaling**: Escalabilidade automática baseada em CPU/memória

## 💰 Otimizações de Custo

1. **Instâncias Spot**: Redução de até 70% nos custos de compute
2. **Auto Scaling**: Recursos ajustados automaticamente à demanda
3. **RDS Scheduled Scaling**: Banco escala conforme necessário
4. **CloudWatch Alarms**: Monitoramento inteligente de custos
5. **Backup Lifecycle**: Retenção otimizada de backups

## 📊 Monitoramento

- Dashboard CloudWatch personalizado
- Alertas de performance e custos
- Logs centralizados
- Métricas customizadas de workflows

## 🔒 Segurança

- VPC isolada com subnets privadas
- Grupos de segurança restritivos
- Secrets Manager para credenciais
- SSL/TLS end-to-end
- IAM roles com princípio de menor privilégio

## 📚 Documentação

Consulte a pasta `docs/` para documentação detalhada sobre:

- [Configuração Local](docs/local-setup.md)
- [Deploy AWS](docs/aws-deployment.md)
- [Otimização de Custos](docs/cost-optimization.md)
- [Monitoramento](docs/monitoring.md)
- [Solução de Problemas](docs/troubleshooting.md)

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🆘 Suporte

Para suporte, abra uma issue no GitHub ou entre em contato através do email.

---

**Desenvolvido para AgroValue** 🌱