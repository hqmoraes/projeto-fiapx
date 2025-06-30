.PHONY: test test-unit coverage build clean help

SERVICE_NAME := upload-service

# Colors
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

test: test-unit ## Executar todos os testes

test-unit: ## Executar testes unitários
	@echo "$(BLUE)Executando testes unitários para $(SERVICE_NAME)...$(NC)"
	go test -v ./tests/unit/... -short

coverage: ## Gerar relatório de cobertura
	@echo "$(BLUE)Gerando relatório de cobertura para $(SERVICE_NAME)...$(NC)"
	go test -coverprofile=coverage.out ./tests/unit/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Relatório de cobertura gerado: coverage.html$(NC)"

build: ## Build do serviço
	@echo "$(BLUE)Building $(SERVICE_NAME)...$(NC)"
	go build -o bin/$(SERVICE_NAME) ./cmd/$(SERVICE_NAME)/

clean: ## Limpar arquivos temporários
	@echo "$(BLUE)Limpando arquivos temporários...$(NC)"
	rm -rf bin/
	rm -f coverage.out coverage.html

deps: ## Instalar dependências
	@echo "$(BLUE)Instalando dependências...$(NC)"
	go mod download
	go mod tidy

help: ## Exibir esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
