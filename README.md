# 🎥 FIAP-X - Sistema de Processamento de Vídeos

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com)
[![Coverage](https://img.shields.io/badge/coverage-85.8%25-green)](https://github.com)
[![Kubernetes](https://img.shields.io/badge/kubernetes-ready-blue)](https://kubernetes.io)
[![HTTPS](https://img.shields.io/badge/HTTPS-enabled-green)](https://fiapx.wecando.click)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Sistema escalável de processamento de vídeos construído com arquitetura de microsserviços, rodando em produção na AWS com observabilidade completa, HTTPS personalizado e notificações automáticas por email.

## 🚀 Funcionalidades

- ✅ **Processamento Paralelo**: Múltiplos vídeos processados simultaneamente
- ✅ **Alta Disponibilidade**: Sistema não perde requisições mesmo em picos
- ✅ **Autenticação Segura**: JWT-based authentication
- ✅ **Monitoramento Real-time**: Status tracking com atualizações em tempo real
- ✅ **Auto-scaling**: HPA baseado em CPU e memória
- ✅ **Observabilidade**: Métricas Prometheus + Dashboards Grafana
- ✅ **CI/CD Completo**: Pipeline automatizado com quality gates
- ✅ **HTTPS Personalizado**: SSL/TLS via CloudFront + domínio personalizado
- ✅ **Notificações Email**: Sistema automático de notificações por email

## 🌐 Acesso ao Sistema

- **🔗 URL Principal**: [https://fiapx.wecando.click](https://fiapx.wecando.click)
- **📊 Monitoramento**: Grafana integrado com métricas em tempo real
- **📧 Notificações**: Emails automáticos sobre status de processamento

## 🏗️ Arquitetura

### Microsserviços Implementados

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Frontend    │◄──►│ CloudFront  │◄──►│ Load Balancer│
│ (HTML/JS)   │    │ + SSL/HTTPS │    │ (K8s)       │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
    ┌─────────▼─┐ ┌──────▼──┐ ┌──────▼──────┐
    │Auth Service│ │Upload   │ │Processing   │
    │(Go + JWT)  │ │Service  │ │Service      │
    └────────────┘ │(Go)     │ │(Go+FFmpeg)  │
                   └─────────┘ └─────────────┘
                          │           │
                   ┌──────▼──────┐    │
                   │Storage      │    │
                   │Service (Go) │    │
                   └─────────────┘    │
                                      │
                              ┌──────▼──────┐
                              │Notification │
                              │Service      │
                              │(Email SMTP) │
                              └─────────────┘
```

A arquitetura do projeto é baseada em microsserviços, com os seguintes componentes:

- **CloudFront + SSL**: CDN global com certificado SSL para https://fiapx.wecando.click
- **API Gateway**: Ponto de entrada único para a aplicação, responsável por roteamento e autenticação.
- **Serviço de Autenticação**: Gerencia usuários e emite tokens JWT.
- **Serviço de Upload**: Recebe e valida os vídeos enviados pelos usuários.
- **Serviço de Processamento**: Processa os vídeos utilizando FFmpeg.
- **Serviço de Armazenamento**: Gerencia o armazenamento e acesso aos vídeos processados.
- **Serviço de Notificação**: Envia emails automáticos sobre status de processamento.

A comunicação entre os serviços é realizada de forma assíncrona através do RabbitMQ, garantindo desacoplamento e resiliência.

Para mais detalhes, consulte o [documento de arquitetura](arquitetura-microsservicos.md) e o [diagrama](arquitetura-microsservicos.html).

## Estrutura do Projeto

```
projeto-fiapx/
├── api-gateway/                  # Serviço de API Gateway
├── auth-service/                 # Serviço de Autenticação
├── upload-service/               # Serviço de Upload
├── processing-service/           # Serviço de Processamento
├── storage-service/              # Serviço de Armazenamento
├── infrastructure/               # Configurações de Infraestrutura
│   ├── docker-compose.yml        # Para desenvolvimento local
│   └── kubernetes/               # Manifestos Kubernetes
├── docs/                         # Documentação do projeto
└── scripts/                      # Scripts utilitários
```

## Requisitos

- Go 1.21 ou superior
- Docker e Docker Compose
- FFmpeg (para desenvolvimento local)
- Kubernetes (para produção)

## Início Rápido

### 1. Configuração Inicial

```bash
# Clonar o repositório
git clone https://github.com/fiap/projeto-fiapx.git
cd projeto-fiapx

# Executar o script de setup
./scripts/setup.sh
```

### 2. Desenvolvimento Local

```bash
# Iniciar todos os serviços com Docker Compose
cd infrastructure
docker-compose up -d
```

Acesse:
- API Gateway: http://localhost:8080
- RabbitMQ Admin: http://localhost:15672 (usuário: guest, senha: guest)
- MinIO Console: http://localhost:9001 (usuário: minioadmin, senha: minioadmin)
- Grafana: http://localhost:3000 (usuário: admin, senha: admin)

### 3. Deploy Completo em Produção (AWS)

```bash
# Deploy completo com HTTPS + Email + Observabilidade
./scripts/deploy-production-complete.sh
```

Este script automaticamente:
- ✅ Configura HTTPS com CloudFront e SSL
- ✅ Deploy de todos os microsserviços
- ✅ Configura notificações por email
- ✅ Instala stack de observabilidade
- ✅ Configura auto-scaling e HPA

### 4. Configuração de HTTPS

```bash
# Configurar domínio personalizado com SSL
./infrastructure/https-cloudfront/setup-https-cloudfront.sh
```

### 5. Configuração de Email

```bash
# Configurar notificações por email
./scripts/setup-email-notifications.sh
```

## 🌐 URLs de Acesso

### Produção
- **Sistema Principal**: https://fiapx.wecando.click

### Desenvolvimento Local
- API Gateway: http://localhost:8080
- RabbitMQ Admin: http://localhost:15672 (usuário: guest, senha: guest)
- MinIO Console: http://localhost:9001 (usuário: minioadmin, senha: minioadmin)
- Grafana: http://localhost:3000 (usuário: admin, senha: admin)

## 📧 Sistema de Notificações

O sistema envia emails automáticos para usuários sobre:
- ✅ Processamento concluído com sucesso
- ❌ Erros durante o processamento
- ⏳ Início do processamento
- 📊 Atualizações de status

### Configuração de Email
1. Usar Gmail ou Google Workspace
2. Habilitar 2FA na conta Google
3. Criar App Password
4. Configurar via script: `./scripts/setup-email-notifications.sh`

## 🔧 Scripts de Automação

### Deploy e Configuração
- `./scripts/deploy-production-complete.sh` - Deploy completo em produção
- `./infrastructure/https-cloudfront/setup-https-cloudfront.sh` - Configuração HTTPS
- `./scripts/setup-email-notifications.sh` - Configuração de email
- `./scripts/deploy-observability-aws.sh` - Deploy de observabilidade

### Desenvolvimento
- `./scripts/build-all.sh [tag] [registry]` - Build de todas as imagens
- `./scripts/deploy.sh [namespace] [environment]` - Deploy no Kubernetes

### Validação
- `./infrastructure/https-cloudfront/validate-https.sh` - Validar HTTPS
- `./scripts/generate-evidence-report.sh` - Gerar relatório de evidências

## 📋 Documentação Adicional

### Arquitetura e Implementação
- [📋 Documentação da Arquitetura](DOCUMENTACAO-ARQUITETURA.md) - Arquitetura completa do sistema
- [📝 Plano de Implementação - Fase 1](plano-implementacao-fase1.md)
- [📐 Diretivas do Projeto](Diretivas.txt)
- [🏗️ Arquitetura de Microsserviços](arquitetura-microsservicos.md)

### Scripts e Configuração
- [🎬 Roteiro para Vídeo de Apresentação](ROTEIRO-VIDEO-APRESENTACAO.md)
- [✅ Checklist Final de Entrega](CHECKLIST-FINAL-ENTREGA.md)
- [📊 Relatório de Observabilidade](OBSERVABILITY-SUCCESS-REPORT.md)
- [📈 Entrega Final Completa](ENTREGA-FINAL-COMPLETA.md)

### Documentação dos Microsserviços
- [🔐 Auth Service](auth-service/README.md) - Autenticação e JWT
- [🚪 API Gateway](api-gateway/README.md) - Roteamento e proxy
- [📤 Upload Service](upload-service/README.md) - Upload de vídeos
- [⚙️ Processing Service](processing-service/README.md) - Processamento FFmpeg
- [💾 Storage Service](storage-service/README.md) - Gerenciamento de arquivos
- [📧 Notification Service](notification-service/README.md) - Notificações por email
- [🌐 Frontend](frontend/README.md) - Interface web

## 🛠️ Desenvolvimento

Cada microsserviço tem sua própria documentação detalhada em seu diretório. Consulte o README.md de cada serviço para:
- 🔧 Configuração local
- 🧪 Execução de testes
- 📊 Métricas e monitoramento
- 🐛 Troubleshooting
- 🚀 Deploy individual

## 📞 Suporte e Troubleshooting

### Logs e Monitoramento
```bash
# Ver logs de todos os pods
kubectl get pods -n fiapx
kubectl logs -f deployment/api-gateway -n fiapx

# Verificar métricas
kubectl port-forward svc/grafana 3000:3000 -n fiapx
# Acesse: http://localhost:3000

# Testar notificações por email
kubectl exec -it deployment/notification-service -n fiapx -- /bin/sh -c \
  "SEND_TEST_EMAIL=true TEST_EMAIL=your@email.com ./notification-service"
```

## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes.


