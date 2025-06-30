#!/bin/bash

# Script simplificado para inicializar estrutura de testes
# Projeto FIAP-X

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Inicializando Estrutura de Testes (Simples) - Projeto FIAP-X${NC}"
echo ""

# Lista de microsserviços
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Função para criar estrutura básica
create_basic_structure() {
    local service=$1
    echo -e "${YELLOW}📁 Criando estrutura básica para $service...${NC}"
    
    cd $service
    
    # Criar diretórios se não existirem
    mkdir -p internal/{handlers,services,repositories,models}
    mkdir -p tests/{unit,integration,e2e}
    mkdir -p cmd/$service
    mkdir -p pkg/{config,database,redis,logger}
    
    echo -e "${GREEN}✅ Estrutura criada para $service${NC}"
    cd ..
}

# Função para criar go.mod básico
init_basic_go_module() {
    local service=$1
    echo -e "${YELLOW}🔧 Inicializando módulo Go básico para $service...${NC}"
    
    cd $service
    
    if [ ! -f "go.mod" ]; then
        go mod init github.com/fiap/projeto-fiapx/$service
        echo -e "${GREEN}✅ go.mod criado para $service${NC}"
    else
        echo -e "${BLUE}ℹ️  go.mod já existe para $service${NC}"
    fi
    
    # Adicionar apenas dependências essenciais
    go get github.com/stretchr/testify@v1.8.4
    go get github.com/gorilla/mux@v1.8.0
    
    go mod tidy
    
    cd ..
}

# Função para criar teste unitário simples
create_simple_unit_test() {
    local service=$1
    echo -e "${YELLOW}🧪 Criando teste unitário simples para $service...${NC}"
    
    cd $service
    
    # Criar exemplo de teste básico
    cat > tests/unit/basic_test.go << 'EOF'
package unit

import (
	"testing"
	"github.com/stretchr/testify/assert"
)

// TestBasicFunction - exemplo de teste unitário básico
func TestBasicFunction(t *testing.T) {
	// Arrange
	input := "test"
	expected := "test"
	
	// Act
	result := input
	
	// Assert
	assert.Equal(t, expected, result)
}

// TestMathOperations - exemplo de teste de operações matemáticas
func TestMathOperations(t *testing.T) {
	tests := []struct {
		name     string
		a, b     int
		expected int
	}{
		{"add_positive", 2, 3, 5},
		{"add_negative", -1, -2, -3},
		{"add_zero", 0, 5, 5},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.a + tt.b
			assert.Equal(t, tt.expected, result)
		})
	}
}
EOF
    
    cd ..
}

# Função para criar Makefile simples
create_simple_makefile() {
    local service=$1
    echo -e "${YELLOW}📋 Criando Makefile simples para $service...${NC}"
    
    cd $service
    
    cat > Makefile << 'EOF'
.PHONY: test test-unit coverage build clean help

SERVICE_NAME := SERVICE_NAME

# Colors
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

test: test-unit ## Executar todos os testes

test-unit: ## Executar testes unitários
	@echo "$(BLUE)Executando testes unitários para $(SERVICE_NAME)...$(NC)"
	go test -v ./tests/unit/...

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
    
    sed -i "s/SERVICE_NAME/$service/g" Makefile
    
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
        
        create_basic_structure "$service"
        init_basic_go_module "$service"
        create_simple_unit_test "$service"
        create_simple_makefile "$service"
        
        echo -e "${GREEN}✅ $service configurado com sucesso!${NC}"
    done
    
    echo ""
    echo -e "${GREEN}🎉 Estrutura básica de testes inicializada com sucesso!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Próximos passos:${NC}"
    echo -e "1. Execute: ${BLUE}make deps${NC} em cada serviço"
    echo -e "2. Execute: ${BLUE}make test${NC} para rodar os testes"
    echo -e "3. Execute: ${BLUE}make coverage${NC} para verificar cobertura"
    echo ""
    echo -e "${BLUE}Para ver todos os comandos disponíveis: make help${NC}"
}

# Executar função principal
main "$@"
