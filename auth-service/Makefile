.PHONY: test test-unit test-integration test-e2e coverage lint build clean

# Configurações
auth-service := auth-service
GO_VERSION := 1.21
COVERAGE_THRESHOLD := 80

# Cores
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

test: test-unit test-integration ## Executar todos os testes

test-unit: ## Executar testes unitários
	@echo "$(BLUE)Executando testes unitários para $(auth-service)...$(NC)"
	go test -v ./tests/unit/... -short

test-integration: ## Executar testes de integração
	@echo "$(BLUE)Executando testes de integração para $(auth-service)...$(NC)"
	go test -v -tags=integration ./tests/integration/...

test-e2e: ## Executar testes E2E
	@echo "$(BLUE)Executando testes E2E para $(auth-service)...$(NC)"
	go test -v ./tests/e2e/...

coverage: ## Gerar relatório de cobertura
	@echo "$(BLUE)Gerando relatório de cobertura para $(auth-service)...$(NC)"
	go test -coverprofile=coverage.out ./tests/unit/...
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
	@echo "$(BLUE)Executando linter para $(auth-service)...$(NC)"
	golangci-lint run ./...

build: ## Build do serviço
	@echo "$(BLUE)Building $(auth-service)...$(NC)"
	go build -o bin/$(auth-service) ./cmd/$(auth-service)/

docker-build: ## Build da imagem Docker
	@echo "$(BLUE)Building imagem Docker para $(auth-service)...$(NC)"
	docker build -t fiapx-$(auth-service):latest .

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
	@echo "$(BLUE)Iniciando $(auth-service) em modo de desenvolvimento...$(NC)"
	go run ./cmd/$(auth-service)/

help: ## Exibir esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
