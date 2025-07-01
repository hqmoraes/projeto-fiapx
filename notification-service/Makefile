# Notification Service Makefile
# FIAP-X Project

# Variables
DOCKER_IMAGE = hmoraes/notification-service
VERSION ?= latest
GO_VERSION = 1.21
NAMESPACE = fiapx

# Go related variables
GOCMD = go
GOBUILD = $(GOCMD) build
GOCLEAN = $(GOCMD) clean
GOTEST = $(GOCMD) test
GOGET = $(GOCMD) get
GOMOD = $(GOCMD) mod
BINARY_NAME = notification-service
BINARY_PATH = ./cmd/notification-service

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m # No Color

.PHONY: help build test clean docker-build docker-push deploy lint security-scan

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo '$(YELLOW)Available commands:$(NC)'
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build the application
	@echo "$(YELLOW)Building $(BINARY_NAME)...$(NC)"
	$(GOBUILD) -v -o $(BINARY_NAME) $(BINARY_PATH)
	@echo "$(GREEN)Build completed!$(NC)"

test: ## Run tests
	@echo "$(YELLOW)Running tests...$(NC)"
	$(GOTEST) -v -race -coverprofile=coverage.out ./...
	@echo "$(GREEN)Tests completed!$(NC)"

test-coverage: test ## Run tests with coverage report
	@echo "$(YELLOW)Generating coverage report...$(NC)"
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Coverage report generated: coverage.html$(NC)"

clean: ## Clean build files
	@echo "$(YELLOW)Cleaning...$(NC)"
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f coverage.out coverage.html
	@echo "$(GREEN)Clean completed!$(NC)"

deps: ## Download dependencies
	@echo "$(YELLOW)Downloading dependencies...$(NC)"
	$(GOMOD) download
	$(GOMOD) tidy
	@echo "$(GREEN)Dependencies updated!$(NC)"

lint: ## Run golangci-lint
	@echo "$(YELLOW)Running linter...$(NC)"
	golangci-lint run --timeout=10m
	@echo "$(GREEN)Linting completed!$(NC)"

security-scan: ## Run security scan with gosec
	@echo "$(YELLOW)Running security scan...$(NC)"
	gosec ./...
	@echo "$(GREEN)Security scan completed!$(NC)"

docker-build: ## Build Docker image
	@echo "$(YELLOW)Building Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(VERSION) .
	docker tag $(DOCKER_IMAGE):$(VERSION) $(DOCKER_IMAGE):latest
	@echo "$(GREEN)Docker image built: $(DOCKER_IMAGE):$(VERSION)$(NC)"

docker-build-multiarch: ## Build multi-architecture Docker image
	@echo "$(YELLOW)Building multi-architecture Docker image...$(NC)"
	docker buildx build --platform linux/amd64,linux/arm64 -t $(DOCKER_IMAGE):$(VERSION) -t $(DOCKER_IMAGE):latest --push .
	@echo "$(GREEN)Multi-architecture Docker image built and pushed!$(NC)"

docker-push: docker-build ## Push Docker image
	@echo "$(YELLOW)Pushing Docker image...$(NC)"
	docker push $(DOCKER_IMAGE):$(VERSION)
	docker push $(DOCKER_IMAGE):latest
	@echo "$(GREEN)Docker image pushed!$(NC)"

docker-run: ## Run Docker container locally
	@echo "$(YELLOW)Running Docker container...$(NC)"
	docker run --rm -it \
		-e RABBITMQ_URL=amqp://guest:guest@localhost:5672/ \
		-e SMTP_HOST=smtp.example.com \
		-e SMTP_PORT=587 \
		-e FROM_EMAIL=test@example.com \
		$(DOCKER_IMAGE):$(VERSION)

k8s-deploy: ## Deploy to Kubernetes
	@echo "$(YELLOW)Deploying to Kubernetes...$(NC)"
	kubectl apply -f k8s/deployment.yaml
	kubectl rollout status deployment/notification-service -n $(NAMESPACE) --timeout=300s
	@echo "$(GREEN)Deployment completed!$(NC)"

k8s-delete: ## Delete from Kubernetes
	@echo "$(YELLOW)Deleting from Kubernetes...$(NC)"
	kubectl delete -f k8s/deployment.yaml
	@echo "$(GREEN)Resources deleted!$(NC)"

k8s-logs: ## Show Kubernetes logs
	kubectl logs -f deployment/notification-service -n $(NAMESPACE)

k8s-status: ## Show Kubernetes status
	@echo "$(YELLOW)Kubernetes Status:$(NC)"
	kubectl get pods,svc -l app=notification-service -n $(NAMESPACE)

setup-secrets: ## Setup Kubernetes secrets (requires manual input)
	@echo "$(YELLOW)Setting up Kubernetes secrets...$(NC)"
	@echo "$(RED)This will prompt for SES credentials$(NC)"
	@read -p "Enter SES SMTP Username: " username; \
	read -s -p "Enter SES SMTP Password: " password; \
	echo; \
	kubectl create secret generic ses-email-secrets \
		--from-literal=ses-smtp-username=$$username \
		--from-literal=ses-smtp-password=$$password \
		--namespace=$(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(GREEN)Secrets created!$(NC)"

dev-setup: deps ## Setup development environment
	@echo "$(YELLOW)Setting up development environment...$(NC)"
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install github.com/securecodewarrior/sast-scan/cmd/gosec@latest
	@echo "$(GREEN)Development environment ready!$(NC)"

ci: lint security-scan test docker-build ## Run CI pipeline locally

all: clean deps lint security-scan test build ## Run all quality checks and build

version: ## Show version information
	@echo "$(YELLOW)Version Information:$(NC)"
	@echo "Go version: $(shell go version)"
	@echo "Docker image: $(DOCKER_IMAGE):$(VERSION)"
	@echo "Binary: $(BINARY_NAME)"
