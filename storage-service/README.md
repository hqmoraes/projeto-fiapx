# Serviço de Armazenamento

O `storage-service` gerencia o armazenamento e o acesso aos arquivos de vídeo da plataforma. Ele utiliza o MinIO, um servidor de armazenamento de objetos compatível com a API do Amazon S3.

## Funcionalidades

- **Armazenamento de Objetos**: Guarda os vídeos originais e os processados em buckets.
- **API Compatível com S3**: Facilita a integração com outras ferramentas e serviços.
- **Segurança**: Gerencia as políticas de acesso aos arquivos.
- **Escalabilidade**: Pode ser configurado em modo distribuído para alta disponibilidade.

## Execução

Para executar o Serviço de Armazenamento localmente, utilize o Docker Compose:

```bash
docker-compose up -d storage-service
```

No ambiente de produção, o deploy é gerenciado pelo workflow de CI/CD do Kubernetes.

# Storage Service

## Descrição

O Storage Service é um microsserviço responsável pelo armazenamento e gerenciamento de vídeos e frames processados no sistema FIAP X. Utiliza MinIO (S3-compatible) para armazenamento de objetos, RabbitMQ para comunicação assíncrona e fornece APIs REST para gerenciamento de dados.

## Tecnologias

- **Linguagem**: Go 1.22+
- **Framework**: Gorilla Mux (HTTP Router)
- **Storage**: MinIO (S3-compatible)
- **Messaging**: RabbitMQ (AMQP)
- **Auth**: JWT (JSON Web Tokens)
- **Métricas**: Prometheus
- **Containerização**: Docker

## Estrutura do Projeto

```
storage-service/
├── cmd/
│   └── storage-service/
│       └── main.go              # Ponto de entrada da aplicação
├── internal/                    # Código interno do serviço
├── pkg/                        # Pacotes reutilizáveis
├── tests/                      # Testes unitários e integração
├── Dockerfile                  # Imagem Docker
├── Makefile                    # Comandos de build e execução
├── go.mod                      # Dependências Go
└── go.sum                      # Checksums das dependências
```

## Funcionalidades

### 📁 Armazenamento de Vídeos
- Upload de vídeos originais
- Armazenamento de frames processados
- Geração de URLs presignadas para download
- Gerenciamento de metadados de vídeos

### 🗄️ Gerenciamento de Dados
- CRUD de informações de vídeos
- Armazenamento de estatísticas de processamento
- Cache de metadados em memória
- Sincronização com serviços externos

### 📊 Monitoramento
- Métricas Prometheus integradas
- Health checks da aplicação
- Logs estruturados de operações
- Monitoramento de recursos

## Endpoints da API

### Autenticação
Todos os endpoints (exceto health) requerem autenticação JWT via header `Authorization: Bearer <token>`.

### Vídeos
- `GET /videos` - Lista vídeos do usuário
- `GET /videos/{id}` - Detalhes de um vídeo específico
- `POST /videos` - Registra novo vídeo no sistema
- `PUT /videos/{id}` - Atualiza informações do vídeo
- `DELETE /videos/{id}` - Remove vídeo do sistema

### Download de Arquivos
- `GET /download/{videoId}` - Download do vídeo original
- `GET /download/{videoId}/frames` - Download dos frames processados (ZIP)

### Estatísticas
- `GET /stats` - Estatísticas do usuário (total de vídeos, armazenamento usado)
- `GET /stats/system` - Estatísticas do sistema (admin apenas)

### Health Check
- `GET /health` - Status do serviço e dependências

## Variáveis de Ambiente

### Configuração do Servidor
```bash
PORT=8080                           # Porta do servidor HTTP
```

### MinIO (S3)
```bash
MINIO_ENDPOINT=localhost:9000       # Endpoint do MinIO
MINIO_ACCESS_KEY=minioadmin         # Chave de acesso
MINIO_SECRET_KEY=minioadmin         # Chave secreta
MINIO_USE_SSL=false                 # Usar SSL/TLS
MINIO_BUCKET_NAME=fiapx-videos      # Nome do bucket
```

### RabbitMQ
```bash
RABBITMQ_URL=amqp://guest:guest@localhost:5672/  # URL de conexão RabbitMQ
```

### JWT
```bash
JWT_SECRET=your-super-secret-jwt-key-here        # Chave secreta JWT
```

### Configuração em Kubernetes
```bash
# Produção (valores obtidos de ConfigMaps/Secrets)
MINIO_ENDPOINT=minio-service:9000
RABBITMQ_URL=amqp://guest:guest@rabbitmq-service:5672/
```

## Instalação e Execução

### Pré-requisitos
- Go 1.22+
- MinIO Server
- RabbitMQ Server
- Docker (opcional)

### Desenvolvimento Local

1. **Instalar dependências**:
```bash
go mod download
```

2. **Configurar variáveis de ambiente**:
```bash
cp .env.example .env
# Editar .env com suas configurações
```

3. **Executar o serviço**:
```bash
make run
# ou
go run cmd/storage-service/main.go
```

### Docker

1. **Build da imagem**:
```bash
make docker-build
# ou
docker build -t storage-service .
```

2. **Executar container**:
```bash
docker run -p 8080:8080 \
  -e MINIO_ENDPOINT=host.docker.internal:9000 \
  -e RABBITMQ_URL=amqp://guest:guest@host.docker.internal:5672/ \
  storage-service
```

### Kubernetes

Deploy no cluster usando os manifestos em `infrastructure/k8s/`:
```bash
kubectl apply -f infrastructure/k8s/storage-service/
```

## Testes

### Executar todos os testes
```bash
make test
```

### Testes com cobertura
```bash
make test-coverage
```

### Testes de integração
```bash
make test-integration
```

### Testes específicos
```bash
# Testar apenas handlers HTTP
go test ./internal/handlers -v

# Testar storage
go test ./internal/storage -v
```

## Métricas Prometheus

O serviço expõe métricas no endpoint `/metrics`:

### Métricas Customizadas
- `storage_videos_total` - Total de vídeos armazenados
- `storage_upload_duration_seconds` - Duração de uploads
- `storage_download_duration_seconds` - Duração de downloads
- `storage_bucket_size_bytes` - Tamanho usado no bucket
- `storage_operations_total` - Total de operações por tipo

### Métricas Padrão Go
- `go_memstats_*` - Estatísticas de memória
- `go_goroutines` - Número de goroutines
- `process_*` - Métricas do processo

## Troubleshooting

### Problemas Comuns

#### 1. Erro de conexão com MinIO
```
Error: failed to connect to MinIO
```
**Solução**: Verificar se o MinIO está rodando e as credenciais estão corretas.

#### 2. Falha na autenticação JWT
```
Error: invalid or expired token
```
**Solução**: Verificar se o JWT_SECRET está configurado e igual ao auth-service.

#### 3. Bucket não encontrado
```
Error: bucket does not exist
```
**Solução**: Criar o bucket no MinIO ou verificar o nome em `MINIO_BUCKET_NAME`.

#### 4. RabbitMQ desconectado
```
Error: connection closed
```
**Solução**: Verificar conexão com RabbitMQ e configurar reconnection.

### Logs e Debug

#### Habilitar logs detalhados
```bash
export LOG_LEVEL=debug
```

#### Verificar status do serviço
```bash
curl http://localhost:8080/health
```

#### Monitorar métricas
```bash
curl http://localhost:8080/metrics
```

### Comandos Úteis

#### Verificar conectividade MinIO
```bash
# Testar conexão
mc alias set local http://localhost:9000 minioadmin minioadmin
mc ls local/
```

#### Verificar filas RabbitMQ
```bash
# Listar filas
rabbitmqctl list_queues
```

#### Logs do container
```bash
docker logs storage-service -f
```

## Desenvolvimento

### Estrutura de Código

#### Handlers HTTP
- Localização: `internal/handlers/`
- Responsabilidade: Processar requisições HTTP
- Padrões: REST, middleware, validação

#### Storage Layer
- Localização: `internal/storage/`
- Responsabilidade: Interação com MinIO
- Funcionalidades: Upload, download, metadados

#### Messaging
- Localização: `internal/messaging/`
- Responsabilidade: Comunicação RabbitMQ
- Padrões: Producer/Consumer, retry logic

### Padrões de Código

- **Clean Architecture**: Separação clara de responsabilidades
- **Dependency Injection**: Inversão de dependências
- **Error Handling**: Tratamento consistente de erros
- **Logging**: Logs estruturados e níveis apropriados

### Contribuição

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## Performance e Otimização

### Recomendações

1. **Conexões Pool**: Usar pool de conexões para MinIO e RabbitMQ
2. **Caching**: Implementar cache Redis para metadados frequentes
3. **Compressão**: Comprimir uploads grandes automaticamente
4. **Cleanup**: Implementar limpeza automática de arquivos antigos

### Monitoramento

- **Latência**: Monitorar tempo de resposta das APIs
- **Throughput**: Acompanhar taxa de uploads/downloads
- **Recursos**: CPU, memória e I/O do serviço
- **Erros**: Taxa de erro por endpoint

## Segurança

### Implementado
- ✅ Autenticação JWT obrigatória
- ✅ Validação de permissões por usuário
- ✅ URLs presignadas com expiração
- ✅ Sanitização de inputs
- ✅ Rate limiting (via API Gateway)

### Recomendações
- Implementar criptografia de arquivos sensíveis
- Audit logs para operações críticas
- Backup automático dos dados
- Monitoramento de segurança

---

## Contato

- **Projeto**: FIAP X - Video Processing Platform
- **Repositório**: GitHub (privado)
- **Documentação**: Ver `DOCUMENTACAO-ARQUITETURA.md` na raiz do projeto
