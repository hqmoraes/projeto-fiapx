# 🎥 FIAP-X - Sistema de Processamento de Vídeos

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/fiapx-project/fiapx-processing-service/actions)
[![Coverage](https://img.shields.io/badge/coverage-85.8%25-green)](https://github.com)
[![Kubernetes](https://img.shields.io/badge/kubernetes-ready-blue)](https://kubernetes.io)
[![HTTPS](https://img.shields.io/badge/HTTPS-enabled-green)](https://fiapx.wecando.click)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Sistema escalável de processamento de vídeos construído com arquitetura de microsserviços, rodando em produção na AWS com CI/CD robusto, segurança, observabilidade completa, HTTPS personalizado e notificações automáticas por email.**

## 🌐 Acesso ao Sistema

- **🔗 URL Principal**: [https://fiapx.wecando.click](https://fiapx.wecando.click)
- **📊 Monitoramento**: Dashboards Grafana com métricas em tempo real.
- **📧 Notificações**: Emails automáticos sobre status de processamento.

## 🚀 Funcionalidades Principais

- ✅ **Processamento Paralelo**: Múltiplos vídeos processados simultaneamente com FFmpeg.
- ✅ **Alta Disponibilidade**: Arquitetura resiliente para suportar picos de carga.
- ✅ **Autenticação Segura**: Autenticação baseada em JWT.
- ✅ **Monitoramento Real-time**: Acompanhamento de status com atualizações em tempo real.
- ✅ **Auto-scaling**: HPA (Horizontal Pod Autoscaler) baseado em CPU e memória.
- ✅ **Observabilidade Completa**: Métricas com Prometheus e dashboards com Grafana.
- ✅ **CI/CD Robusto**: Pipeline automatizado com quality gates, testes e deploy seguro.
- ✅ **HTTPS Personalizado**: SSL/TLS via CloudFront com domínio personalizado.
- ✅ **Notificações por Email**: Sistema automático de notificações via SMTP.

## 🏗️ Arquitetura de Microsserviços

A arquitetura do projeto é baseada em microsserviços, garantindo escalabilidade, resiliência e manutenibilidade.

Para mais detalhes, consulte o [documento de arquitetura](arquitetura-microsservicos.md) e o [diagrama](arquitetura-microsservicos.html).

## 🛠️ Estrutura do Projeto

```
projeto-fiapx/
├── .github/workflows/          # Workflows de CI/CD (GitHub Actions)
├── api-gateway/                # Serviço de API Gateway
├── auth-service/               # Serviço de Autenticação
├── frontend/                   # Aplicação Frontend (HTML/JS)
├── notification-service/       # Serviço de Notificação por Email
├── processing-service/         # Serviço de Processamento de Vídeos
├── storage-service/            # Serviço de Armazenamento (MinIO)
├── upload-service/             # Serviço de Upload de Vídeos
├── infrastructure/             # Configurações de Infraestrutura (Kubernetes)
├── scripts/                    # Scripts de automação e utilitários
└── README.md                   # Documentação principal
```

## 🔒 Segurança e CI/CD

O projeto segue as melhores práticas de segurança e automação, incluindo:

- **Proteção de Branches**: A branch `main` é protegida, exigindo aprovação de Pull Requests.
- **CI/CD Automatizado**: Workflows de GitHub Actions para build, teste, e deploy em staging e produção.
- **Gerenciamento de Secrets**: Utilização de GitHub Secrets para armazenar credenciais de forma segura.
- **Análise de Segurança**: Ferramentas para verificação de vulnerabilidades e credenciais expostas.

Para mais detalhes, consulte a [documentação de segurança e CI/CD](GITHUB-SECRETS-COMPLETE-SETUP.md).

## ⚙️ Como Executar

### Pré-requisitos

- Go 1.21+
- Docker e Docker Compose
- Kubernetes (Minikube, Kind, ou um cluster na nuvem)
- `kubectl`

### Desenvolvimento Local

Para configurar o ambiente de desenvolvimento local, utilize o Docker Compose:

```bash
# Iniciar todos os serviços
docker-compose up -d
```

### Deploy no Kubernetes

Para realizar o deploy no Kubernetes, utilize os scripts e manifestos disponíveis no diretório `infrastructure/kubernetes`.

```bash
# Aplicar os manifestos do Kubernetes
kubectl apply -f infrastructure/kubernetes/
```

## 📜 Licença

Este projeto está licenciado sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.
