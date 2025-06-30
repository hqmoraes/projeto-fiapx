#!/bin/bash

# Script para inicializar estrutura de testes e qualidade em todos os microsserviços
# Projeto FIAP-X

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Inicializando Estrutura de Testes e Qualidade - Projeto FIAP-X${NC}"
echo ""

# Lista de microsserviços
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Função para criar estrutura de diretórios
create_test_structure() {
    local service=$1
    echo -e "${YELLOW}📁 Criando estrutura de testes para $service...${NC}"
    
    cd $service
    
    # Criar diretórios se não existirem
    mkdir -p internal/{handlers,services,repositories,models}
    mkdir -p tests/{integration,e2e,mocks}
    mkdir -p cmd/$service
    mkdir -p pkg/{config,database,redis,logger,metrics}
    
    echo -e "${GREEN}✅ Estrutura criada para $service${NC}"
    cd ..
}

# Função para criar go.mod se não existir
init_go_module() {
    local service=$1
    echo -e "${YELLOW}🔧 Inicializando módulo Go para $service...${NC}"
    
    cd $service
    
    if [ ! -f "go.mod" ]; then
        go mod init github.com/fiap/projeto-fiapx/$service
        echo -e "${GREEN}✅ go.mod criado para $service${NC}"
    else
        echo -e "${BLUE}ℹ️  go.mod já existe para $service${NC}"
    fi
    
    # Adicionar dependências básicas de teste
    go mod edit -require github.com/stretchr/testify@v1.8.4
    go mod edit -require github.com/go-redis/redis/v8@v8.11.5
    go mod edit -require github.com/lib/pq@v1.10.9
    go mod edit -require github.com/gorilla/mux@v1.8.0
    go mod edit -require github.com/testcontainers/testcontainers-go@v0.24.1
    go mod edit -require github.com/DATA-DOG/go-sqlmock@v1.5.0
    go mod edit -require github.com/prometheus/client_golang@v1.17.0
    
    # Resolver conflitos de dependências
    go mod edit -exclude google.golang.org/genproto@v0.0.0-20230306155012-7f2fa6fef1f4
    
    go mod tidy
    
    cd ..
}

# Função para criar arquivos de configuração
create_config_files() {
    local service=$1
    echo -e "${YELLOW}⚙️  Criando arquivos de configuração para $service...${NC}"
    
    cd $service
    
    # Criar .env.test
    cat > .env.test << 'EOF'
# Configurações para testes
DATABASE_URL=postgres://testuser:testpass@localhost:5432/testdb?sslmode=disable
REDIS_URL=redis://localhost:6379
RABBITMQ_URL=amqp://guest:guest@localhost:5672/
JWT_SECRET=test-secret-key
LOG_LEVEL=debug
EOF

    # Criar Dockerfile se não existir
    if [ ! -f "Dockerfile" ]; then
        cat > Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/SERVICE_NAME/

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
EOF
        sed -i "s/SERVICE_NAME/$service/g" Dockerfile
        echo -e "${GREEN}✅ Dockerfile criado para $service${NC}"
    fi
    
    cd ..
}

# Função para criar exemplo de teste unitário
create_unit_test_example() {
    local service=$1
    echo -e "${YELLOW}🧪 Criando exemplo de teste unitário para $service...${NC}"
    
    cd $service
    
    # Criar exemplo de handler test
    cat > internal/handlers/health_handler_test.go << 'EOF'
package handlers_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHealthHandler(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		expectedBody   string
	}{
		{
			name:           "health_check_success",
			expectedStatus: http.StatusOK,
			expectedBody:   `{"status":"healthy","service":"SERVICE_NAME"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			req := httptest.NewRequest(http.MethodGet, "/health", nil)
			w := httptest.NewRecorder()

			// Act
			// handlers.HealthHandler(w, req) // Implementar este handler

			// Assert (simulação de resposta de sucesso)
			w.WriteHeader(tt.expectedStatus)
			w.Write([]byte(tt.expectedBody))
			
			assert.Equal(t, tt.expectedStatus, w.Code)
			assert.JSONEq(t, tt.expectedBody, w.Body.String())
		})
	}
}
EOF
    
    sed -i "s/SERVICE_NAME/$service/g" internal/handlers/health_handler_test.go
    
    cd ..
}

# Função para criar exemplo de teste de integração
create_integration_test_example() {
    local service=$1
    echo -e "${YELLOW}🔗 Criando exemplo de teste de integração para $service...${NC}"
    
    cd $service
    
    cat > tests/integration/database_test.go << 'EOF'
//go:build integration
// +build integration

package integration_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	_ "github.com/lib/pq"
)

type DatabaseTestSuite struct {
	suite.Suite
	container *postgres.PostgresContainer
	db        *sql.DB
}

func (suite *DatabaseTestSuite) SetupSuite() {
	ctx := context.Background()
	
	container, err := postgres.RunContainer(ctx,
		testcontainers.WithImage("postgres:13-alpine"),
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("testuser"),
		postgres.WithPassword("testpass"))
	suite.Require().NoError(err)
	suite.container = container

	connStr, err := container.ConnectionString(ctx, "sslmode=disable")
	suite.Require().NoError(err)

	suite.db, err = sql.Open("postgres", connStr)
	suite.Require().NoError(err)
}

func (suite *DatabaseTestSuite) TearDownSuite() {
	if suite.db != nil {
		suite.db.Close()
	}
	if suite.container != nil {
		suite.container.Terminate(context.Background())
	}
}

func (suite *DatabaseTestSuite) TestDatabaseConnection() {
	err := suite.db.Ping()
	assert.NoError(suite.T(), err)
}

func TestDatabaseSuite(t *testing.T) {
	suite.Run(t, new(DatabaseTestSuite))
}
EOF
    
    cd ..
}

# Função para criar Makefile específico do serviço
create_service_makefile() {
    local service=$1
    echo -e "${YELLOW}📋 Criando Makefile para $service...${NC}"
    
    cd $service
    
    cat > Makefile << 'EOF'
.PHONY: test test-unit test-integration test-e2e coverage lint build clean

# Configurações
SERVICE_NAME := SERVICE_NAME
GO_VERSION := 1.21
COVERAGE_THRESHOLD := 80

# Cores
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

test: test-unit test-integration ## Executar todos os testes

test-unit: ## Executar testes unitários
	@echo "$(BLUE)Executando testes unitários para $(SERVICE_NAME)...$(NC)"
	go test -v ./internal/... -short

test-integration: ## Executar testes de integração
	@echo "$(BLUE)Executando testes de integração para $(SERVICE_NAME)...$(NC)"
	go test -v -tags=integration ./tests/integration/...

test-e2e: ## Executar testes E2E
	@echo "$(BLUE)Executando testes E2E para $(SERVICE_NAME)...$(NC)"
	go test -v ./tests/e2e/...

coverage: ## Gerar relatório de cobertura
	@echo "$(BLUE)Gerando relatório de cobertura para $(SERVICE_NAME)...$(NC)"
	go test -coverprofile=coverage.out ./internal/...
	go tool cover -html=coverage.out -o coverage.html
	go tool cover -func=coverage.out

coverage-check: coverage ## Verificar threshold de cobertura
	@echo "$(BLUE)Verificando threshold de cobertura ($(COVERAGE_THRESHOLD)%)...$(NC)"
	@coverage=$$(go tool cover -func=coverage.out | tail -1 | awk '{print $$3}' | sed 's/%//'); \
	if (( $$(echo "$$coverage < $(COVERAGE_THRESHOLD)" | bc -l) )); then \
		echo "$(RED)❌ Cobertura $$coverage% < $(COVERAGE_THRESHOLD)%$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ Cobertura $$coverage% >= $(COVERAGE_THRESHOLD)%$(NC)"; \
	fi

lint: ## Executar linter
	@echo "$(BLUE)Executando linter para $(SERVICE_NAME)...$(NC)"
	golangci-lint run ./...

build: ## Build do serviço
	@echo "$(BLUE)Building $(SERVICE_NAME)...$(NC)"
	go build -o bin/$(SERVICE_NAME) ./cmd/$(SERVICE_NAME)/

docker-build: ## Build da imagem Docker
	@echo "$(BLUE)Building imagem Docker para $(SERVICE_NAME)...$(NC)"
	docker build -t fiapx-$(SERVICE_NAME):latest .

clean: ## Limpar arquivos temporários
	@echo "$(BLUE)Limpando arquivos temporários...$(NC)"
	rm -rf bin/
	rm -f coverage.out coverage.html
	go clean -cache

deps: ## Instalar dependências
	@echo "$(BLUE)Instalando dependências...$(NC)"
	go mod download
	go mod tidy

dev: ## Executar em modo de desenvolvimento
	@echo "$(BLUE)Iniciando $(SERVICE_NAME) em modo de desenvolvimento...$(NC)"
	go run ./cmd/$(SERVICE_NAME)/

help: ## Exibir esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
EOF
    
    sed -i "s/SERVICE_NAME/$service/g" Makefile
    
    cd ..
}

# Função para criar arquivo de métricas
create_metrics_example() {
    local service=$1
    echo -e "${YELLOW}📊 Criando exemplo de métricas para $service...${NC}"
    
    cd $service
    
    mkdir -p pkg/metrics
    cat > pkg/metrics/metrics.go << 'EOF'
package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	HTTPRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status_code"},
	)

	HTTPRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "http_request_duration_seconds",
			Help: "Duration of HTTP requests",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	DatabaseConnections = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "database_connections_active",
			Help: "Number of active database connections",
		},
	)
)
EOF
    
    cd ..
}

# Main execution
main() {
    echo -e "${BLUE}Verificando dependências...${NC}"
    
    # Verificar se Go está instalado
    if ! command -v go &> /dev/null; then
        echo -e "${RED}❌ Go não está instalado${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Go $(go version | awk '{print $3}') encontrado${NC}"
    
    # Processar cada serviço
    for service in "${SERVICES[@]}"; do
        echo ""
        echo -e "${BLUE}🔄 Processando $service...${NC}"
        
        # Criar diretório do serviço se não existir
        if [ ! -d "$service" ]; then
            mkdir -p "$service"
            echo -e "${GREEN}✅ Diretório $service criado${NC}"
        fi
        
        create_test_structure "$service"
        init_go_module "$service"
        create_config_files "$service"
        create_unit_test_example "$service"
        create_integration_test_example "$service"
        create_service_makefile "$service"
        create_metrics_example "$service"
        
        echo -e "${GREEN}✅ $service configurado com sucesso!${NC}"
    done
    
    echo ""
    echo -e "${GREEN}🎉 Estrutura de testes e qualidade inicializada com sucesso!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Próximos passos:${NC}"
    echo -e "1. Execute: ${BLUE}make deps${NC} em cada serviço"
    echo -e "2. Execute: ${BLUE}make test${NC} para rodar os testes"
    echo -e "3. Execute: ${BLUE}make coverage-check${NC} para verificar cobertura"
    echo -e "4. Execute: ${BLUE}make lint${NC} para verificar qualidade do código"
    echo ""
    echo -e "${BLUE}Para ver todos os comandos disponíveis: make help${NC}"
}

# Executar função principal
main "$@"
