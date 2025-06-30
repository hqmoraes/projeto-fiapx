# ⚙️ Processing Service - FIAP-X

## 📋 Descrição

O Processing Service é o núcleo do sistema FIAP-X, responsável pelo processamento paralelo de vídeos usando FFmpeg. Extrai frames dos vídeos, gerencia workers paralelos e fornece observabilidade completa com métricas Prometheus.

## 🎯 Posição na Arquitetura

```
RabbitMQ Queue → Processing Service → MinIO Storage
       ↑               ↓                    ↓
   Job Creator    Redis Cache         Processed Frames
```

### Dependências
- **Input**: RabbitMQ (jobs queue)
- **Storage**: MinIO (vídeos + frames extraídos)
- **Cache**: Redis (status + progress tracking)
- **Database**: PostgreSQL (job metadata)
- **Tools**: FFmpeg (video processing)

## ⚙️ Funcionalidades

### 🔑 Core Features
- ✅ **Processamento paralelo** de múltiplos vídeos
- ✅ **Extração de frames** usando FFmpeg
- ✅ **Workers escaláveis** com controle de concorrência
- ✅ **Progress tracking** em tempo real via Redis
- ✅ **Auto-scaling** via HPA (Horizontal Pod Autoscaler)
- ✅ **Error recovery** com retry automático
- ✅ **Cache de resultados** para otimização

### 🔄 Workflow de Processamento
1. **Job Pickup**: Worker pega job da fila RabbitMQ
2. **Download**: Baixa vídeo do MinIO storage
3. **Processing**: Extrai frames usando FFmpeg
4. **Upload**: Envia frames processados para MinIO
5. **Update**: Atualiza status no Redis e PostgreSQL
6. **Cleanup**: Remove arquivos temporários
7. **Acknowledge**: Confirma processamento do job

### 📊 Observabilidade Completa
- **Prometheus Metrics**: CPU, Memory, Goroutines, Jobs
- **Health Checks**: Endpoints de saúde
- **Structured Logs**: JSON logs para agregação
- **Performance Tracking**: Métricas de processamento

## 🌐 API Endpoints

### `GET /health`
Health check do serviço

**Response (200):**
```json
{
  "status": "healthy",
  "timestamp": "2025-06-30T19:00:00Z",
  "dependencies": {
    "rabbitmq": "connected",
    "minio": "connected", 
    "redis": "connected",
    "postgres": "connected",
    "ffmpeg": "available"
  },
  "workers": {
    "active": 3,
    "max": 5,
    "queue_size": 12
  }
}
```

### `GET /metrics`
Prometheus metrics (formato OpenMetrics)

**Response (200):**
```
# HELP processing_jobs_total Total number of jobs processed
# TYPE processing_jobs_total counter
processing_jobs_total{status="completed"} 1234
processing_jobs_total{status="error"} 23

# HELP processing_active_workers Number of active workers
# TYPE processing_active_workers gauge
processing_active_workers 3

# HELP processing_queue_size Number of jobs in queue
# TYPE processing_queue_size gauge
processing_queue_size 12
```

### `GET /stats`
Estatísticas de processamento

**Response (200):**
```json
{
  "workers": {
    "active": 3,
    "max_concurrent": 5,
    "total_spawned": 47
  },
  "jobs": {
    "processed_today": 156,
    "total_processed": 2341,
    "average_duration": "45.6s",
    "success_rate": 98.2
  },
  "performance": {
    "frames_per_second": 24.5,
    "avg_processing_time": "1.2s/frame"
  }
}
```

### `POST /process/{job_id}/retry`
Reprocessar job específico (admin only)

**Headers:**
```
Authorization: Bearer <admin_jwt_token>
```

**Response (200):**
```json
{
  "success": true,
  "job_id": "uuid-1234",
  "status": "RETRY_QUEUED",
  "message": "Job requeued for processing"
}
```

## 🔧 Configuração

### Variáveis de Ambiente

```bash
# Server
PORT=8080
GIN_MODE=release

# Worker Configuration
MAX_CONCURRENT_VIDEOS=5      # Máximo vídeos simultâneos
WORKER_TIMEOUT=300           # 5 minutos timeout
FFMPEG_THREADS=2             # Threads FFmpeg por worker
FRAMES_PER_SECOND=1          # Frames extraídos por segundo

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
RABBITMQ_QUEUE=video_processing
RABBITMQ_PREFETCH=1          # Jobs por worker

# MinIO Storage  
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_USE_SSL=false
MINIO_VIDEO_BUCKET=videos
MINIO_FRAMES_BUCKET=frames

# Redis Cache
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=
REDIS_TTL=3600               # 1 hour cache

# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=fiapx

# FFmpeg Options
FFMPEG_PATH=/usr/bin/ffmpeg
FFMPEG_OUTPUT_FORMAT=png
FFMPEG_SCALE=640:480         # Redimensionar frames
FFMPEG_QUALITY=2             # Qualidade (1-31, menor = melhor)
```

### Configuração de Workers

```yaml
workers:
  max_concurrent: 5
  timeout: 300s
  retry_attempts: 3
  retry_delay: 30s
  
processing:
  frames_per_second: 1
  output_format: "png"
  scale: "640:480"
  quality: 2
  
cleanup:
  temp_files: true
  temp_dir: "/tmp/processing"
  cleanup_interval: "1h"
```

## 🏗️ Estrutura do Projeto

```
processing-service/
├── cmd/
│   └── processing-service/
│       └── main.go             # Entry point
├── internal/
│   ├── config/
│   │   └── config.go           # Configuration
│   ├── worker/
│   │   ├── manager.go          # Worker manager
│   │   ├── processor.go        # Video processor
│   │   └── pool.go             # Worker pool
│   ├── handlers/
│   │   ├── health.go           # Health check
│   │   ├── metrics.go          # Metrics endpoint
│   │   └── stats.go            # Statistics
│   ├── services/
│   │   ├── ffmpeg.go           # FFmpeg wrapper
│   │   ├── storage.go          # MinIO integration
│   │   ├── queue.go            # RabbitMQ consumer
│   │   ├── cache.go            # Redis operations
│   │   └── database.go         # PostgreSQL ops
│   ├── models/
│   │   ├── job.go              # Job model
│   │   └── frame.go            # Frame model
│   └── utils/
│       ├── cleanup.go          # File cleanup
│       └── validation.go       # Input validation
├── pkg/
│   ├── metrics/
│   │   └── metrics.go          # Prometheus metrics
│   └── logger/
│       └── logger.go           # Structured logging
├── tests/
│   ├── integration/
│   │   ├── worker_test.go      # Worker tests
│   │   └── ffmpeg_test.go      # FFmpeg tests
│   └── unit/
│       ├── processor_test.go   # Processing tests
│       └── cache_test.go       # Cache tests
├── scripts/
│   ├── test-videos/            # Test video files
│   └── benchmark.sh            # Performance tests
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

# Testes unitários
make test-unit

# Testes de integração (requer FFmpeg)
make test-integration

# Benchmark de performance
make benchmark

# Cobertura de testes
make test-coverage
```

### Cenários de Teste

1. **Processamento básico de MP4**
2. **Processamento paralelo de múltiplos vídeos**
3. **Tratamento de erro em vídeo corrompido**
4. **Retry automático em falha temporária**
5. **Cache hit/miss scenarios**
6. **Worker timeout handling**
7. **Progress tracking accuracy**
8. **Cleanup de arquivos temporários**
9. **FFmpeg error handling**
10. **Memory management sob carga**
11. **Queue acknowledgment**
12. **Health check dependencies**
13. **Metrics accuracy**
14. **Scale up/down behavior**
15. **Redis failover**

### Cobertura Atual
- **Coverage**: 88.9%
- **Cenários**: 15 testes principais
- **Mocks**: RabbitMQ, MinIO, Redis, PostgreSQL
- **Integration**: FFmpeg real tests

## 📊 Métricas Detalhadas

### Application Metrics

```go
# Jobs processados
processing_jobs_total{status="completed|error|timeout"}

# Workers ativos
processing_active_workers

# Duração de processamento
processing_duration_seconds{job_type}

# Frames extraídos
processing_frames_extracted_total

# Queue size
processing_queue_size

# Falhas por tipo
processing_errors_total{error_type}

# Cache hits/misses
processing_cache_operations_total{operation="hit|miss"}

# Memory usage
processing_memory_usage_bytes

# FFmpeg executions
processing_ffmpeg_executions_total{status}
```

### Business Metrics

```go
# Throughput
processing_videos_per_hour

# Average processing time
processing_avg_duration_seconds

# Success rate
processing_success_rate_percentage

# Storage efficiency
processing_storage_saved_bytes
```

### Performance Metrics

```go
# Go runtime
go_goroutines
go_gc_duration_seconds
go_memstats_*

# HTTP server
promhttp_metric_handler_requests_total
http_request_duration_seconds
```

## 🚀 Deployment

### Docker

```bash
# Build
docker build -t fiapx-processing-service .

# Run
docker run -p 8080:8080 \
  -e RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/ \
  -e MAX_CONCURRENT_VIDEOS=3 \
  fiapx-processing-service
```

### Kubernetes com HPA

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: processing-service
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: processing-service
        image: hmoraes/fiapx-processing-service:v-observability
        ports:
        - containerPort: 8080
        env:
        - name: MAX_CONCURRENT_VIDEOS
          value: "1"  # 1 vídeo por pod
        - name: FFMPEG_THREADS  
          value: "2"
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "800Mi"
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: processing-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: processing-service
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## 🔍 Troubleshooting

### Problemas Comuns

**Workers não processam jobs:**
```bash
# Verificar queue RabbitMQ
rabbitmqctl list_queues

# Verificar logs
kubectl logs -f deployment/processing-service

# Verificar conexões
curl http://processing-service:8080/health
```

**FFmpeg falha:**
```bash
# Testar FFmpeg manualmente
ffmpeg -i test.mp4 -vf fps=1 frame_%03d.png

# Verificar instalação
ffmpeg -version

# Verificar permissões
ls -la /tmp/processing/
```

**Alto uso de CPU:**
```bash
# Verificar workers ativos
curl http://processing-service:8080/stats

# Verificar HPA
kubectl get hpa processing-service-hpa

# Reduzir concorrência
kubectl set env deployment/processing-service MAX_CONCURRENT_VIDEOS=2
```

**Cache miss alto:**
```bash
# Verificar Redis
redis-cli info memory

# Verificar TTL
redis-cli ttl "job:uuid-1234"

# Verificar métricas cache
curl http://processing-service:8080/metrics | grep cache
```

### Logs Importantes

```bash
# Processamento iniciado
INFO: Starting video processing - job_id=uuid-1234 filename=video.mp4

# Frame extraído
DEBUG: Frame extracted - job_id=uuid-1234 frame=123 duration=1.2s

# Processamento concluído
INFO: Video processing completed - job_id=uuid-1234 frames=240 duration=45s

# Erro de processamento
ERROR: FFmpeg failed - job_id=uuid-1234 error="invalid codec"
```

### Monitoramento

```bash
# Workers ativos
watch kubectl get pods -l app=processing-service

# CPU/Memory usage
kubectl top pods -l app=processing-service

# Métricas em tempo real
watch "curl -s http://processing-service:8080/metrics | grep processing_active_workers"
```

## 🔧 Performance Tuning

### Otimização de Workers

```bash
# Para vídeos pequenos (< 10MB)
MAX_CONCURRENT_VIDEOS=5
FFMPEG_THREADS=1

# Para vídeos grandes (> 50MB)  
MAX_CONCURRENT_VIDEOS=2
FFMPEG_THREADS=4

# Para máxima throughput
MAX_CONCURRENT_VIDEOS=10
FFMPEG_THREADS=1
```

### Otimização de FFmpeg

```bash
# Qualidade vs velocidade
FFMPEG_QUALITY=5          # Velocidade
FFMPEG_QUALITY=1          # Qualidade

# Frames por segundo
FRAMES_PER_SECOND=0.5     # Menos frames
FRAMES_PER_SECOND=2       # Mais frames
```

### Otimização de Cache

```bash
# Cache mais agressivo
REDIS_TTL=7200            # 2 horas

# Cache mínimo
REDIS_TTL=300             # 5 minutos
```

## 📚 Documentação Adicional

- [FFmpeg Integration Guide](./docs/ffmpeg.md)
- [Worker Pool Architecture](./docs/workers.md)
- [Caching Strategy](./docs/caching.md)
- [Performance Benchmarks](./docs/benchmarks.md)
- [Scaling Guide](./docs/scaling.md)

---

**📅 Última Atualização:** 30 de Junho de 2025  
**👨‍💻 Maintainer:** Equipe FIAP-X  
**🔗 Repositório:** [GitHub - Processing Service](https://github.com/fiap-x/processing-service)  
**🎯 Status:** ✅ Produção com Auto-scaling Ativo
