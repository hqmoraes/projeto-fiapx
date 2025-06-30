# Plano de Implementação - Qualidade de Código e CI/CD
## Projeto FIAP-X - Sistema de Processamento de Vídeos

### FASE 1: Estrutura de Testes e Qualidade (Semana 1)

#### 1.1 Configuração de Testes para Cada Microsserviço

**auth-service:**
```go
// Estrutura de testes
auth-service/
├── cmd/
│   └── auth-service/
│       ├── main.go
│       └── main_test.go
├── internal/
│   ├── handlers/
│   │   ├── auth_handler.go
│   │   └── auth_handler_test.go
│   ├── services/
│   │   ├── auth_service.go
│   │   └── auth_service_test.go
│   ├── repositories/
│   │   ├── user_repository.go
│   │   └── user_repository_test.go
│   └── models/
│       ├── user.go
│       └── user_test.go
├── tests/
│   ├── integration/
│   │   └── auth_integration_test.go
│   └── e2e/
│       └── auth_e2e_test.go
└── go.mod
```

**Tipos de Testes:**
- **Unit Tests**: Testes de unidade para cada função/método
- **Integration Tests**: Testes de integração com banco de dados/Redis
- **E2E Tests**: Testes ponta a ponta das APIs
- **Benchmark Tests**: Testes de performance

#### 1.2 Ferramentas de Qualidade

**Go Tools:**
```bash
# Linting e formatação
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/segmentio/golines@latest
go install golang.org/x/tools/cmd/goimports@latest

# Cobertura
go install github.com/axw/gocov/gocov@latest
go install github.com/AlekSi/gocov-html@latest

# Análise estática
go install github.com/securecodewarrior/goat@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
```

**Configurações:**
- `.golangci.yml` - Configuração do linter
- `Makefile` - Comandos padronizados
- `go.work` - Workspace Go para múltiplos módulos

#### 1.3 Metas de Cobertura por Serviço

| Serviço | Cobertura Mínima | Foco Principal |
|---------|------------------|----------------|
| auth-service | 85% | JWT, autenticação, validações |
| upload-service | 80% | Validação de arquivos, upload |
| processing-service | 85% | Processamento de vídeo, cache |
| storage-service | 80% | Armazenamento, download |

### FASE 2: Implementação de Testes (Semana 2)

#### 2.1 Testes Unitários

**Exemplo para auth-service:**
```go
// internal/services/auth_service_test.go
func TestAuthService_Login(t *testing.T) {
    // Arrange
    mockRepo := &mocks.UserRepository{}
    service := NewAuthService(mockRepo, "secret")
    
    // Act & Assert
    tests := []struct {
        name     string
        email    string
        password string
        want     *Token
        wantErr  bool
    }{
        {"valid_credentials", "test@test.com", "password", &Token{}, false},
        {"invalid_email", "invalid", "password", nil, true},
        {"invalid_password", "test@test.com", "wrong", nil, true},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

#### 2.2 Testes de Integração

**Exemplo para database:**
```go
// tests/integration/user_repository_test.go
func TestUserRepository_Integration(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    defer teardownTestDB(t, db)
    
    repo := NewUserRepository(db)
    
    // Test CRUD operations
    t.Run("CreateUser", func(t *testing.T) {
        user := &User{Email: "test@test.com", Password: "hash"}
        err := repo.Create(user)
        assert.NoError(t, err)
        assert.NotZero(t, user.ID)
    })
}
```

#### 2.3 Testes E2E

**Exemplo para API:**
```go
// tests/e2e/auth_e2e_test.go
func TestAuthAPI_E2E(t *testing.T) {
    // Setup test server
    server := setupTestServer(t)
    defer server.Close()
    
    client := &http.Client{}
    
    t.Run("RegisterAndLogin", func(t *testing.T) {
        // Register user
        registerReq := RegisterRequest{
            Email: "test@test.com",
            Password: "password123",
        }
        
        resp, err := client.Post(server.URL+"/register", "application/json", 
            bytes.NewBuffer(marshal(registerReq)))
        assert.NoError(t, err)
        assert.Equal(t, 201, resp.StatusCode)
        
        // Login user
        loginReq := LoginRequest{
            Email: "test@test.com",
            Password: "password123",
        }
        
        resp, err = client.Post(server.URL+"/login", "application/json", 
            bytes.NewBuffer(marshal(loginReq)))
        assert.NoError(t, err)
        assert.Equal(t, 200, resp.StatusCode)
    })
}
```

### FASE 3: CI/CD Pipeline (Semana 3)

#### 3.1 GitHub Actions Workflow

**.github/workflows/ci.yml:**
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: fiapx_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Go
      uses: actions/setup-go@v3
      with:
        go-version: 1.21
    
    - name: Cache Go modules
      uses: actions/cache@v3
      with:
        path: ~/go/pkg/mod
        key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
    
    - name: Install dependencies
      run: go mod download
    
    - name: Run linter
      uses: golangci/golangci-lint-action@v3
      with:
        version: latest
    
    - name: Run tests
      run: |
        make test-coverage
        make test-integration
        make test-e2e
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.out
    
    - name: Quality Gate
      run: |
        make quality-gate
```

#### 3.2 Build e Deploy

**.github/workflows/deploy.yml:**
```yaml
name: Deploy

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Build and push images
      run: |
        make build-all
        make push-all
  
  deploy:
    needs: build
    runs-on: ubuntu-latest
    
    steps:
    - name: Deploy to Kubernetes
      run: |
        kubectl apply -f infrastructure/kubernetes/
        kubectl rollout restart deployment/auth-service -n fiapx
        kubectl rollout restart deployment/upload-service -n fiapx
        kubectl rollout restart deployment/processing-service -n fiapx
        kubectl rollout restart deployment/storage-service -n fiapx
```

### FASE 4: Monitoramento e Observabilidade (Semana 4)

#### 4.1 Métricas com Prometheus

**Instrumentação em Go:**
```go
// pkg/metrics/metrics.go
var (
    HTTPRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status_code"},
    )
    
    HTTPRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "Duration of HTTP requests",
        },
        []string{"method", "endpoint"},
    )
    
    VideoProcessingTime = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "video_processing_duration_seconds",
            Help: "Duration of video processing",
        },
        []string{"video_size", "format"},
    )
)
```

#### 4.2 Configuração Grafana

**Dashboard para cada serviço:**
- Request rate, latency, error rate
- Database connections
- Cache hit rate
- Queue size
- Resource usage (CPU, Memory)

#### 4.3 Alerting

**Prometheus Alerts:**
```yaml
# alerts.yml
groups:
- name: fiapx-alerts
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"
  
  - alert: DatabaseDown
    expr: up{job="postgres"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Database is down"
```

### FASE 5: Segurança e Validações (Semana 5)

#### 5.1 Security Scanning

**Dependências:**
```yaml
# .github/workflows/security.yml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'

- name: Run Gosec Security Scanner
  uses: securecodewarrior/github-action-gosec@master
```

#### 5.2 Input Validation

**Exemplo de validação robusta:**
```go
// pkg/validation/validator.go
type VideoUploadRequest struct {
    File     multipart.File `validate:"required"`
    Filename string         `validate:"required,min=1,max=255"`
    Size     int64          `validate:"required,min=1,max=2097152"` // 2MB
    MimeType string         `validate:"required,oneof=video/mp4 video/avi video/mov"`
}

func (r *VideoUploadRequest) Validate() error {
    validate := validator.New()
    
    if err := validate.Struct(r); err != nil {
        return err
    }
    
    // Custom validations
    if !isValidVideoFormat(r.Filename) {
        return errors.New("invalid video format")
    }
    
    return nil
}
```

### ENTREGÁVEIS

#### 1. **Código com Qualidade**
- [ ] Testes unitários com >80% cobertura
- [ ] Testes de integração
- [ ] Testes E2E automatizados
- [ ] Linting e formatação automática
- [ ] Análise estática de código

#### 2. **CI/CD Pipeline**
- [ ] GitHub Actions configurado
- [ ] Build automatizado
- [ ] Deploy automatizado
- [ ] Rollback automático em caso de falha
- [ ] Ambientes de staging e produção

#### 3. **Monitoramento**
- [ ] Métricas Prometheus
- [ ] Dashboards Grafana
- [ ] Alerting configurado
- [ ] Logs centralizados
- [ ] Tracing distribuído

#### 4. **Segurança**
- [ ] Scanning de vulnerabilidades
- [ ] Validação de inputs
- [ ] Secrets management
- [ ] Network policies
- [ ] RBAC configurado

#### 5. **Documentação**
- [ ] README atualizado
- [ ] API documentation (Swagger)
- [ ] Runbooks operacionais
- [ ] Guias de troubleshooting

### CRONOGRAMA

| Semana | Foco | Entregáveis |
|--------|------|-------------|
| 1 | Estrutura de testes | Configuração de ferramentas, estrutura de pastas |
| 2 | Implementação de testes | Testes unitários, integração, E2E |
| 3 | CI/CD Pipeline | GitHub Actions, build/deploy automatizado |
| 4 | Monitoramento | Prometheus, Grafana, alerting |
| 5 | Segurança e finalizações | Security scanning, validações, documentação |

### PRÓXIMOS PASSOS

1. **Criar estrutura de testes** para todos os microsserviços
2. **Implementar testes unitários** focando em >80% cobertura
3. **Configurar CI/CD** com GitHub Actions
4. **Implementar monitoramento** com Prometheus/Grafana
5. **Adicionar security scanning** e validações
6. **Documentar tudo** e criar guias operacionais

**Resultado esperado:** Sistema de produção com qualidade enterprise, testes automatizados, CI/CD completo e monitoramento avançado.
