# Projeto FiapX - Processamento de Vídeos

## Visão Geral

Este projeto implementa uma plataforma de processamento de vídeos baseada em microsserviços, com foco em escalabilidade, resiliência e manutenibilidade.

## Arquitetura

A arquitetura do projeto é baseada em microsserviços, com os seguintes componentes:

- **API Gateway**: Ponto de entrada único para a aplicação, responsável por roteamento e autenticação.
- **Serviço de Autenticação**: Gerencia usuários e emite tokens JWT.
- **Serviço de Upload**: Recebe e valida os vídeos enviados pelos usuários.
- **Serviço de Processamento**: Processa os vídeos utilizando FFmpeg.
- **Serviço de Armazenamento**: Gerencia o armazenamento e acesso aos vídeos processados.

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

### 3. Build das Imagens Docker

```bash
# Construir todas as imagens
./scripts/build-all.sh [tag] [registry]
```

### 4. Implantação no Kubernetes

```bash
# Implantar no Kubernetes
./scripts/deploy.sh [namespace] [environment]
```

## Desenvolvimento

Cada microsserviço tem sua própria documentação detalhada em seu diretório. Consulte o README.md de cada serviço para mais informações.

## Documentação Adicional

- [Plano de Implementação - Fase 1](plano-implementacao-fase1.md)
- [Diretivas do Projeto](Diretivas.txt)
- [Arquitetura de Microsserviços](arquitetura-microsservicos.md)

## Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes.
