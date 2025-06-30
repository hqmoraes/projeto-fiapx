# Makefile para Projeto FIAP-X
# Comandos padronizados para desenvolvimento, testes e deploy

.PHONY: help test test-unit test-integration test-e2e coverage lint build clean docker deploy

# Variáveis
GO_VERSION := 1.21
DOCKER_REGISTRY := hmoraes
PROJECT_NAME := fiapx
COVERAGE_THRESHOLD := 80

# Cores para output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Exibe esta ajuda
	@echo "$(BLUE)Projeto FIAP-X - Comandos Disponíveis$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

## Comandos de Desenvolvimento
deps: ## Instala dependências
	@echo "$(BLUE)Instalando dependências...$(NC)"
	go mod download
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/axw/gocov/gocov@latest
	go install github.com/AlekSi/gocov-html@latest
	go install golang.org/x/tools/cmd/cover@latest

fmt: ## Formatar código
	@echo "$(BLUE)Formatando código...$(NC)"
	go fmt ./...
	goimports -w .

lint: ## Executar linter
	@echo "$(BLUE)Executando linter...$(NC)"
	golangci-lint run ./...

## Comandos de Teste
test: test-unit test-integration ## Executar todos os testes

test-unit: ## Executar testes unitários
	@echo "$(BLUE)Executando testes unitários...$(NC)"
	cd auth-service && go test -v ./internal/... -short
	cd upload-service && go test -v ./internal/... -short
	cd processing-service && go test -v ./internal/... -short
	cd storage-service && go test -v ./internal/... -short

test-integration: ## Executar testes de integração
	@echo "$(BLUE)Executando testes de integração...$(NC)"
	cd auth-service && go test -v ./tests/integration/...
	cd upload-service && go test -v ./tests/integration/...
	cd processing-service && go test -v ./tests/integration/...
	cd storage-service && go test -v ./tests/integration/...

test-e2e: ## Executar testes E2E
	@echo "$(BLUE)Executando testes E2E...$(NC)"
	cd auth-service && go test -v ./tests/e2e/...
	cd upload-service && go test -v ./tests/e2e/...
	cd processing-service && go test -v ./tests/e2e/...
	cd storage-service && go test -v ./tests/e2e/...

coverage: ## Gerar relatório de cobertura
	@echo "$(BLUE)Gerando relatório de cobertura...$(NC)"
	@for service in auth-service upload-service processing-service storage-service; do \
		echo "$(YELLOW)Cobertura para $$service:$(NC)"; \
		cd $$service && \
		go test -coverprofile=coverage.out ./internal/... && \
		go tool cover -html=coverage.out -o coverage.html && \
		go tool cover -func=coverage.out | tail -1 && \
		cd ..; \
	done

coverage-check: coverage ## Verificar se cobertura atende ao threshold
	@echo "$(BLUE)Verificando threshold de cobertura ($(COVERAGE_THRESHOLD)%)...$(NC)"
	@for service in auth-service upload-service processing-service storage-service; do \
		cd $$service && \
		coverage=$$(go tool cover -func=coverage.out | tail -1 | awk '{print $$3}' | sed 's/%//') && \
		if (( $$(echo "$$coverage < $(COVERAGE_THRESHOLD)" | bc -l) )); then \
			echo "$(RED)❌ $$service: Cobertura $$coverage% < $(COVERAGE_THRESHOLD)%$(NC)"; \
			exit 1; \
		else \
			echo "$(GREEN)✅ $$service: Cobertura $$coverage% >= $(COVERAGE_THRESHOLD)%$(NC)"; \
		fi && \
		cd ..; \
	done

quality-gate: lint coverage-check ## Gate de qualidade completo
	@echo "$(GREEN)✅ Quality Gate passou!$(NC)"

## Comandos de Build
build: ## Build de todos os serviços
	@echo "$(BLUE)Building todos os serviços...$(NC)"
	cd auth-service && go build -o ../bin/auth-service ./cmd/auth-service/
	cd upload-service && go build -o ../bin/upload-service ./cmd/upload-service/
	cd processing-service && go build -o ../bin/processing-service ./cmd/processing-service/
	cd storage-service && go build -o ../bin/storage-service ./cmd/storage-service/

docker-build: ## Build das imagens Docker
	@echo "$(BLUE)Building imagens Docker...$(NC)"
	cd auth-service && docker build -t $(DOCKER_REGISTRY)/$(PROJECT_NAME)-auth-service:latest .
	cd upload-service && docker build -t $(DOCKER_REGISTRY)/$(PROJECT_NAME)-upload-service:latest .
	cd processing-service && docker build -t $(DOCKER_REGISTRY)/$(PROJECT_NAME)-processing-service:latest .
	cd storage-service && docker build -t $(DOCKER_REGISTRY)/$(PROJECT_NAME)-storage-service:latest .

docker-push: docker-build ## Push das imagens Docker
	@echo "$(BLUE)Pushing imagens Docker...$(NC)"
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-auth-service:latest
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-upload-service:latest
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-processing-service:latest
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-storage-service:latest

## Comandos de Deploy
deploy-dev: ## Deploy para ambiente de desenvolvimento
	@echo "$(BLUE)Deploy para desenvolvimento...$(NC)"
	kubectl apply -f infrastructure/kubernetes/ -n fiapx-dev

deploy-prod: quality-gate docker-push ## Deploy para produção (com quality gate)
	@echo "$(BLUE)Deploy para produção...$(NC)"
	kubectl apply -f infrastructure/kubernetes/ -n fiapx
	kubectl rollout restart deployment/auth-service -n fiapx
	kubectl rollout restart deployment/upload-service -n fiapx
	kubectl rollout restart deployment/processing-service -n fiapx
	kubectl rollout restart deployment/storage-service -n fiapx

## Comandos de Monitoramento
logs: ## Ver logs dos serviços
	@echo "$(BLUE)Logs dos serviços:$(NC)"
	kubectl logs -l app=auth-service -n fiapx --tail=50
	kubectl logs -l app=upload-service -n fiapx --tail=50
	kubectl logs -l app=processing-service -n fiapx --tail=50
	kubectl logs -l app=storage-service -n fiapx --tail=50

status: ## Status dos serviços
	@echo "$(BLUE)Status dos serviços:$(NC)"
	kubectl get pods -n fiapx
	kubectl get svc -n fiapx
	kubectl get hpa -n fiapx

health-check: ## Verificar saúde dos serviços
	@echo "$(BLUE)Health check dos serviços:$(NC)"
	@for service in auth upload processing storage; do \
		echo "$(YELLOW)Verificando $$service-service...$(NC)"; \
		curl -f -s http://worker.wecando.click:$(shell kubectl get svc $$service-service-external -n fiapx -o jsonpath='{.spec.ports[0].nodePort}')/health || echo "$(RED)❌ $$service-service não respondeu$(NC)"; \
	done

## Comandos de Limpeza
clean: ## Limpar arquivos temporários
	@echo "$(BLUE)Limpando arquivos temporários...$(NC)"
	rm -rf bin/
	rm -f */coverage.out
	rm -f */coverage.html
	go clean -cache
	docker system prune -f

## Comandos de Setup
setup: deps ## Setup inicial do projeto
	@echo "$(BLUE)Setup inicial do projeto...$(NC)"
	mkdir -p bin/
	@echo "$(GREEN)✅ Projeto configurado!$(NC)"

dev: ## Ambiente de desenvolvimento (com watch)
	@echo "$(BLUE)Iniciando ambiente de desenvolvimento...$(NC)"
	@echo "$(YELLOW)Pressione Ctrl+C para parar$(NC)"
	docker-compose -f infrastructure/docker-compose.dev.yml up

## Comandos de CI/CD
ci: quality-gate ## Pipeline de CI (usado no GitHub Actions)
	@echo "$(GREEN)✅ Pipeline de CI concluída!$(NC)"

cd: docker-push deploy-prod ## Pipeline de CD (usado no GitHub Actions)
	@echo "$(GREEN)✅ Pipeline de CD concluída!$(NC)"
