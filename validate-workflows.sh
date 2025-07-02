#!/bin/bash
# 🔍 Validador de Workflows CI/CD - FIAP-X
# Este script verifica a consistência entre os workflows de CI/CD

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKFLOWS_DIR=".github/workflows"

echo -e "${BLUE}🔍 Validando Workflows CI/CD - FIAP-X${NC}"
echo ""

# Verificar se o diretório de workflows existe
if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    echo -e "${RED}❌ Diretório de workflows não encontrado: $WORKFLOWS_DIR${NC}"
    exit 1
fi

# Contar workflows
workflow_count=$(find "$WORKFLOWS_DIR" -name "*.yml" | wc -l)
echo -e "${BLUE}📊 Encontrados $workflow_count arquivos de workflow${NC}"

# Listar todos os workflows
echo ""
echo -e "${YELLOW}📋 Lista de workflows:${NC}"
for workflow in $(find "$WORKFLOWS_DIR" -name "*.yml"); do
    name=$(grep "^name:" "$workflow" | head -1 | sed 's/name: //')
    echo -e "  • ${GREEN}$(basename "$workflow")${NC} - $name"
done

# Verificar consistência de secrets
echo ""
echo -e "${YELLOW}🔐 Verificando uso de secrets:${NC}"

# Docker Hub
echo -e "${BLUE}🐳 Docker Hub secrets:${NC}"
grep -r "DOCKER_USERNAME\|DOCKERHUB_USERNAME\|DOCKER_PASSWORD\|DOCKERHUB_TOKEN" "$WORKFLOWS_DIR" --include="*.yml" | sort

# Kubernetes
echo -e "${BLUE}☸️  Kubernetes secrets:${NC}"
grep -r "KUBE_CONFIG" "$WORKFLOWS_DIR" --include="*.yml" | sort

# SSH
echo -e "${BLUE}🔑 SSH secrets:${NC}"
grep -r "SSH_PRIVATE_KEY\|SSH_USER\|K8S_HOST" "$WORKFLOWS_DIR" --include="*.yml" | sort

# AWS
echo -e "${BLUE}☁️  AWS secrets:${NC}"
grep -r "AWS_ACCESS_KEY_ID\|AWS_SECRET_ACCESS_KEY" "$WORKFLOWS_DIR" --include="*.yml" | sort

# JWT
echo -e "${BLUE}🔐 JWT secrets:${NC}"
grep -r "JWT_SECRET" "$WORKFLOWS_DIR" --include="*.yml" | sort

# Verificar configuração de triggers
echo ""
echo -e "${YELLOW}🔄 Verificando triggers:${NC}"

# Main branch
echo -e "${BLUE}📌 Triggers na branch main:${NC}"
grep -r -A5 "branches:.*main" "$WORKFLOWS_DIR" --include="*.yml" | sort

# Validar branch
echo -e "${BLUE}📌 Triggers na branch validar:${NC}"
grep -r -A5 "branches:.*validar" "$WORKFLOWS_DIR" --include="*.yml" | sort

# Pull Requests
echo -e "${BLUE}📌 Triggers em Pull Requests:${NC}"
grep -r -A5 "pull_request:" "$WORKFLOWS_DIR" --include="*.yml" | sort

echo ""
echo -e "${GREEN}✅ Validação concluída!${NC}"
echo ""
echo -e "${YELLOW}⚠️  Verifique manualmente:${NC}"
echo "1. Consistência dos nomes de secrets entre workflows"
echo "2. Uso de branches corretas nos triggers"
echo "3. Verificação de que todos os microserviços estão cobertos"

echo ""
echo -e "${BLUE}📝 Próximos passos:${NC}"
echo "1. Corrigir quaisquer inconsistências encontradas"
echo "2. Configurar branch protection"
echo "3. Testar pipeline com um commit"
