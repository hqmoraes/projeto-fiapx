# 📤 Upload Service - FIAP-X

## 📋 Descrição

O Upload Service é responsável pelo gerenciamento de upload de vídeos na plataforma FIAP-X. É o primeiro ponto de contato para arquivos de vídeo enviados pelos usuários, realizando validação, armazenamento temporário e criação de jobs de processamento.

## 🎯 Posição na Arquitetura

```
Frontend → API Gateway → Upload Service → [Storage + Queue]
                              ↓
                         Processing Service
```

### Dependências
- **Upstream**: API Gateway (recebe requisições)
- **Downstream**: MinIO (storage), RabbitMQ (jobs), PostgreSQL (metadata)
- **Cache**: Redis (para tracking)

## ⚙️ Funcionalidades

### 🔑 Core Features
- ✅ **Upload múltiplo de arquivos**
- ✅ **Validação de formato de vídeo** (MP4, AVI, MOV, MKV)
- ✅ **Validação de tamanho** (máx. 100MB por arquivo)
- ✅ **Armazenamento seguro** no MinIO S3-compatible
- ✅ **Criação de jobs** na fila RabbitMQ
- ✅ **Tracking de status** via Redis cache

### 🔒 Segurança
- JWT Token validation
- User-based file isolation
- Sanitização de nomes de arquivo
- Verificação de MIME type

### 📊 Observabilidade
- Metrics Prometheus integradas
- Logs estruturados
- Health check endpoint
- Performance monitoring

## 🌐 API Endpoints

### `POST /upload`
Upload de vídeos para processamento

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: multipart/form-data
```

**Body:**
```
files: [arquivo1.mp4, arquivo2.avi, ...]
```

**Response (200):**
```json
{
  "success": true,
  "message": "Arquivos enviados com sucesso",
  "jobs": [
    {
      "job_id": "uuid-1234",
      "filename": "video1.mp4",
      "status": "PENDING",
      "size": 15728640
    }
  ]
}
```

**Response (400):**
```json
{
  "success": false,
  "error": "Formato de arquivo inválido",
  "details": "Apenas MP4, AVI, MOV são suportados"
}
```

### `GET /status/{job_id}`
Consulta status de um job específico

**Response (200):**
```json
{
  "job_id": "uuid-1234",
  "filename": "video1.mp4",
  "status": "PROCESSING",
  "progress": 45,
  "created_at": "2025-06-30T19:00:00Z",
  "estimated_completion": "2025-06-30T19:05:00Z"
}
```

### `GET /jobs`
Lista todos os jobs do usuário autenticado

**Query Parameters:**
- `status`: filtrar por status (PENDING, PROCESSING, COMPLETED, ERROR)
- `limit`: número de resultados (default: 20)
- `offset`: paginação (default: 0)

### `GET /health`
Health check do serviço

**Response (200):**
```json
{
  "status": "healthy",
  "timestamp": "2025-06-30T19:00:00Z",
  "dependencies": {
    "minio": "connected",
    "rabbitmq": "connected",
    "redis": "connected",
    "postgres": "connected"
  }
}
```

## 🔧 Configuração

### Variáveis de Ambiente

```bash
# Server
PORT=8080
GIN_MODE=release

# Authentication
JWT_SECRET=your-jwt-secret-key

# MinIO Storage
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_USE_SSL=false
MINIO_BUCKET=videos

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
RABBITMQ_QUEUE=video_processing

# Redis Cache
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=fiapx

# Upload Limits
MAX_FILE_SIZE=104857600  # 100MB
MAX_FILES_PER_REQUEST=5
ALLOWED_EXTENSIONS=mp4,avi,mov,mkv
```

### Arquivo de Configuração (config.yaml)

```yaml
server:
  port: 8080
  timeout: 30s

upload:
  max_file_size: 104857600  # 100MB
  max_files: 5
  allowed_extensions: ["mp4", "avi", "mov", "mkv"]
  temp_dir: "/tmp/uploads"

storage:
  provider: "minio"
  bucket: "videos"
  
queue:
  provider: "rabbitmq"
  queue_name: "video_processing"
  
cache:
  provider: "redis"
  ttl: 3600  # 1 hour
```

## 🏗️ Estrutura do Projeto

```
upload-service/
├── cmd/
│   └── upload-service/
│       └── main.go             # Entry point
├── internal/
│   ├── config/
│   │   └── config.go           # Configuration management
│   ├── handlers/
│   │   ├── upload.go           # Upload handlers
│   │   ├── status.go           # Status handlers
│   │   └── health.go           # Health check
│   ├── middleware/
│   │   ├── auth.go             # JWT middleware
│   │   ├── cors.go             # CORS middleware
│   │   └── logging.go          # Request logging
│   ├── models/
│   │   ├── job.go              # Job model
│   │   └── upload.go           # Upload model
│   ├── services/
│   │   ├── storage.go          # MinIO integration
│   │   ├── queue.go            # RabbitMQ integration
│   │   ├── cache.go            # Redis integration
│   │   └── database.go         # PostgreSQL integration
│   └── validators/
│       └── file.go             # File validation
├── pkg/
│   ├── metrics/
│   │   └── metrics.go          # Prometheus metrics
│   └── logger/
│       └── logger.go           # Structured logging
├── tests/
│   ├── integration/
│   │   └── upload_test.go      # Integration tests
│   └── unit/
│       ├── handlers_test.go    # Handler tests
│       └── validators_test.go  # Validation tests
├── Dockerfile                  # Container definition
├── go.mod                      # Go dependencies
├── go.sum                      # Dependency checksums
├── Makefile                    # Build automation
└── README.md                   # This file
```

## 🧪 Testes

### Executar Testes

```bash
# Todos os testes
make test

# Apenas testes unitários
make test-unit

# Apenas testes de integração
make test-integration

# Com cobertura
make test-coverage
```

### Cenários de Teste

1. **Upload válido de arquivo MP4**
2. **Upload múltiplo de arquivos**
3. **Rejeição de formato inválido**
4. **Rejeição de arquivo muito grande**
5. **Autenticação JWT inválida**
6. **Falha de conexão com MinIO**
7. **Falha de conexão com RabbitMQ**
8. **Consulta de status de job**

### Cobertura Atual
- **Coverage**: 82.7%
- **Cenários**: 8 testes principais
- **Mocks**: MinIO, RabbitMQ, Redis, PostgreSQL

## 📊 Métricas

### Prometheus Metrics

```go
# Requests totais
upload_requests_total{method, status, endpoint}

# Duração das requisições
upload_request_duration_seconds{method, endpoint}

# Uploads em andamento
upload_active_uploads

# Tamanho dos arquivos
upload_file_size_bytes

# Erros por tipo
upload_errors_total{type}
```

### Business Metrics

```go
# Jobs criados
upload_jobs_created_total

# Arquivos processados
upload_files_processed_total{status}

# Storage utilizado
upload_storage_bytes_used
```

## 🚀 Deployment

### Docker

```bash
# Build
docker build -t fiapx-upload-service .

# Run
docker run -p 8080:8080 \
  -e MINIO_ENDPOINT=minio:9000 \
  -e RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/ \
  fiapx-upload-service
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: upload-service
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: upload-service
        image: hmoraes/fiapx-upload-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: MINIO_ENDPOINT
          value: "minio:9000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

## 🔍 Troubleshooting

### Problemas Comuns

**Upload falha com timeout:**
```bash
# Verificar conexão com MinIO
curl http://minio:9000/minio/health/live

# Verificar logs
kubectl logs -f deployment/upload-service
```

**Jobs não aparecem na fila:**
```bash
# Verificar RabbitMQ
rabbitmqctl list_queues

# Verificar configuração de queue
curl -u guest:guest http://rabbitmq:15672/api/queues
```

**Cache não funciona:**
```bash
# Verificar Redis
redis-cli ping

# Verificar TTL das chaves
redis-cli ttl "job:uuid-1234"
```

### Logs Importantes

```bash
# Upload bem-sucedido
INFO: File uploaded successfully - filename=video.mp4 size=15MB user_id=123

# Validação falhou
WARN: Invalid file format - filename=document.pdf user_id=123

# Erro de storage
ERROR: Failed to upload to MinIO - error="connection refused"
```

## 📚 Documentação Adicional

- [API Specification (OpenAPI)](./docs/api.yaml)
- [Database Schema](./docs/schema.sql)
- [Deployment Guide](./docs/deployment.md)
- [Performance Tuning](./docs/performance.md)

---

**📅 Última Atualização:** 30 de Junho de 2025  
**👨‍💻 Maintainer:** Equipe FIAP-X  
**🔗 Repositório:** [GitHub - Upload Service](https://github.com/fiap-x/upload-service)  
**🎯 Status:** ✅ Produção Estável
