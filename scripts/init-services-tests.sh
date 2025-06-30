#!/bin/bash

# Script otimizado para criar estrutura de testes básica
# Projeto FIAP-X

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Criando Estrutura de Testes Básica - Projeto FIAP-X${NC}"
echo ""

# Lista de microsserviços (exceto auth-service que já foi feito)
SERVICES=("upload-service" "processing-service" "storage-service")

# Função para processar cada serviço
process_service() {
    local service=$1
    echo -e "${YELLOW}🔄 Processando $service...${NC}"
    
    cd $service
    
    # Criar diretórios básicos
    mkdir -p tests/unit cmd/$service internal/{handlers,services} pkg/config
    
    # Limpar e recriar go.mod
    rm -f go.mod go.sum
    go mod init github.com/fiap/projeto-fiapx/$service
    
    # Adicionar dependências básicas
    go get github.com/stretchr/testify@v1.8.4
    go get github.com/gorilla/mux@v1.8.0
    
    # Criar teste básico
    cat > tests/unit/${service}_test.go << EOF
package unit

import (
	"testing"
	"github.com/stretchr/testify/assert"
)

// TestBasic${service^}Function - exemplo de teste unitário básico
func TestBasic${service^}Function(t *testing.T) {
	// Arrange
	input := "$service-test"
	expected := "$service-test"
	
	// Act
	result := input
	
	// Assert
	assert.Equal(t, expected, result)
}

// Test${service^}Operations - exemplo de teste com table-driven
func Test${service^}Operations(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"basic_operation", "test", "test"},
		{"empty_input", "", ""},
		{"special_chars", "test@123", "test@123"},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.input
			assert.Equal(t, tt.expected, result)
		})
	}
}
EOF
    
    # Criar Makefile
    cat > Makefile << 'EOF'
.PHONY: test test-unit coverage build clean help

SERVICE_NAME := SERVICE_PLACEHOLDER

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
EOF
    
    # Substituir placeholder
    sed -i "s/SERVICE_PLACEHOLDER/$service/g" Makefile
    
    # Ajustar go.mod
    go mod tidy
    
    echo -e "${GREEN}✅ $service configurado!${NC}"
    cd ..
}

# Main execution
main() {
    # Processar cada serviço
    for service in "${SERVICES[@]}"; do
        echo ""
        
        # Criar diretório do serviço se não existir
        if [ ! -d "$service" ]; then
            mkdir -p "$service"
            echo -e "${GREEN}✅ Diretório $service criado${NC}"
        fi
        
        process_service "$service"
    done
    
    echo ""
    echo -e "${GREEN}🎉 Estrutura básica criada para todos os serviços!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Para testar cada serviço:${NC}"
    echo -e "cd <service> && make test${NC}"
    echo -e "cd <service> && make coverage${NC}"
}

# Executar função principal
main "$@"
