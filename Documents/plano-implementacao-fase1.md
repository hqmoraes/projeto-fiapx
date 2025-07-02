# Plano de Implementação - Refatoração para Arquitetura de Microsserviços
## Fase 1: Fundação e Estrutura Básica

### Objetivo da Fase 1
Estabelecer a estrutura básica do projeto refatorado, incluindo a organização de diretórios, configuração inicial dos microsserviços, implementação do sistema de mensageria e configuração do ambiente Kubernetes.

### 1. Estrutura de Diretórios

```
projeto-fiapx/
├── api-gateway/                  # Serviço de API Gateway
│   ├── Dockerfile
│   ├── src/
│   ├── config/
│   └── README.md
│
├── auth-service/                 # Serviço de Autenticação
│   ├── Dockerfile
│   ├── src/
│   ├── config/
│   └── README.md
│
├── upload-service/               # Serviço de Upload
│   ├── Dockerfile
│   ├── src/
│   ├── config/
│   └── README.md
│
├── processing-service/           # Serviço de Processamento
│   ├── Dockerfile
│   ├── src/
│   ├── config/
│   └── README.md
│
├── storage-service/              # Serviço de Armazenamento
│   ├── Dockerfile
│   ├── src/
│   ├── config/
│   └── README.md
│
├── infrastructure/               # Configurações de Infraestrutura
│   ├── docker-compose.yml        # Para desenvolvimento local
│   ├── kubernetes/               # Manifestos Kubernetes
│   │   ├── api-gateway/
│   │   ├── auth-service/
│   │   ├── upload-service/
│   │   ├── processing-service/
│   │   ├── storage-service/
│   │   ├── rabbitmq/
│   │   ├── postgres/
│   │   ├── redis/
│   │   ├── minio/
│   │   └── monitoring/
│   └── terraform/                # IaC (opcional para fase posterior)
│
├── docs/                         # Documentação do projeto
│   ├── architecture/
│   ├── api/
│   └── operations/
│
└── scripts/                      # Scripts utilitários
    ├── setup.sh
    ├── build-all.sh
    └── deploy.sh
```

### 2. Tarefas Detalhadas

#### 2.1 Preparação do Ambiente

1. **Criar estrutura de diretórios**
   - Implementar a estrutura de pastas conforme definido acima
   - Inicializar repositórios Git para cada serviço (ou um monorepo, dependendo da estratégia escolhida)

2. **Configurar ambiente de desenvolvimento**
   - Criar docker-compose.yml para execução local
   - Configurar ferramentas de desenvolvimento (linters, formatters)
   - Definir padrões de código e documentação

3. **Preparar ambiente Kubernetes**
   - Confirmar acesso ao cluster Kubernetes
   - Criar namespaces para desenvolvimento, teste e produção
   - Configurar roles e permissões básicas

#### 2.2 Implementação dos Microsserviços Básicos

1. **Serviço de API Gateway**
   - Implementar roteamento básico
   - Configurar CORS e rate limiting
   - Implementar validação de JWT
   - Tecnologia sugerida: Go com Chi Router ou Gin

2. **Serviço de Autenticação**
   - Implementar registro e login de usuários
   - Gerar e validar tokens JWT
   - Conectar com PostgreSQL para armazenamento de usuários
   - Tecnologia sugerida: Go com pacotes jwt-go e sqlx

3. **Serviço de Upload**
   - Migrar lógica de upload do código monolítico
   - Implementar validação de formatos de vídeo
   - Integrar com sistema de mensageria (RabbitMQ)
   - Tecnologia sugerida: Go com pacotes para manipulação de multipart/form-data

4. **Serviço de Processamento**
   - Migrar lógica de processamento do código monolítico
   - Configurar consumidor de mensagens RabbitMQ
   - Integrar FFmpeg para processamento de vídeo
   - Tecnologia sugerida: Go com integração ao FFmpeg

5. **Serviço de Armazenamento**
   - Implementar upload para MinIO/S3
   - Gerenciar metadados de arquivos no PostgreSQL
   - Implementar geração de URLs assinadas para acesso
   - Tecnologia sugerida: Go com pacotes oficiais AWS S3 ou MinIO

#### 2.3 Configuração da Infraestrutura Básica

1. **Sistema de Mensageria**
   - Implantar RabbitMQ no cluster Kubernetes
   - Configurar exchanges, queues e bindings
   - Implementar padrões de mensagens (contratos)
   - Configurar monitoramento básico

2. **Bancos de Dados**
   - Implantar PostgreSQL no cluster Kubernetes
   - Criar schemas e tabelas iniciais
   - Configurar persistência e backups
   - Implantar Redis para cache

3. **Armazenamento de Objetos**
   - Implantar MinIO no cluster Kubernetes
   - Configurar buckets e políticas de acesso
   - Implementar lifecycle policies para gerenciamento de dados

#### 2.4 Implantação Inicial

1. **Configurar Pipeline CI/CD**
   - Implementar testes automatizados básicos
   - Configurar builds automatizados de imagens Docker
   - Implementar deploy automatizado para ambiente de desenvolvimento

2. **Implantar no Kubernetes**
   - Criar manifestos Kubernetes para cada serviço
   - Configurar ConfigMaps e Secrets para variáveis de ambiente
   - Implementar healthchecks e readiness probes
   - Configurar ingress para acesso externo

3. **Monitoramento Básico**
   - Configurar logging centralizado
   - Implementar métricas básicas em cada serviço
   - Configurar alertas para problemas críticos

### 3. Entregáveis da Fase 1

1. **Código Fonte**
   - Repositórios iniciais para todos os microsserviços
   - Estrutura de projeto e padrões definidos
   - Implementações básicas funcionais

2. **Documentação**
   - Guia de arquitetura atualizado
   - Documentação de APIs (Swagger/OpenAPI)
   - Guias de desenvolvimento e operação

3. **Infraestrutura**
   - Ambiente Kubernetes configurado
   - Serviços de infraestrutura implantados (RabbitMQ, PostgreSQL, Redis, MinIO)
   - Pipeline CI/CD básico funcionando

4. **Demonstração**
   - Upload de vídeo básico funcionando
   - Processamento simples de vídeo
   - Recuperação de vídeo processado

### 4. Critérios de Aceitação

1. Todos os serviços devem estar implantados no cluster Kubernetes
2. O upload, processamento e recuperação básica de vídeos deve funcionar
3. A comunicação entre serviços deve ocorrer via RabbitMQ
4. A autenticação básica deve estar implementada
5. Logs e métricas básicas devem estar disponíveis
6. O pipeline CI/CD deve construir e implantar todas as aplicações

### 5. Próximos Passos

Após a conclusão da Fase 1, seguiremos para a Fase 2, que incluirá:
- Implementação de funcionalidades avançadas de processamento de vídeo
- Melhorias na segurança e resiliência
- Implementação de caching avançado
- Configuração de autoscaling
- Melhorias no monitoramento e observabilidade
