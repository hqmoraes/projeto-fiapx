#!/bin/bash
# 🛡️ Configurador de Branch Protection - FIAP-X
# Este script ajuda a configurar proteção de branches no GitHub

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO="hqmoraes/projeto-fiapx"

echo -e "${BLUE}🛡️ Configurador de Branch Protection - FIAP-X${NC}"
echo -e "${BLUE}Repository: $REPO${NC}"
echo ""

# Verificar dependências
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI não instalado${NC}"
    echo "Instale com: apt install gh (Ubuntu) ou brew install gh (macOS)"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI não autenticado${NC}"
    echo "Execute: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ Pré-requisitos OK${NC}"
echo ""

# Explicação
echo -e "${YELLOW}⚠️  Nota Importante:${NC}"
echo "A proteção de branches deve ser configurada via interface web do GitHub."
echo "Este script vai abrir a página correta, mas você precisará configurar manualmente."
echo ""
echo -e "${BLUE}🔒 Configurações recomendadas:${NC}"
echo "  1. Require a pull request before merging"
echo "  2. Require approvals: 1"
echo "  3. Dismiss stale PR approvals when new commits are pushed"
echo "  4. Require status checks to pass before merging"
echo "  5. Require branches to be up to date before merging"
echo "  6. Ativar 'Do not allow bypassing the above settings'"
echo ""

read -p "Abrir página de configuração? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Operação cancelada"
    exit 0
fi

# Abrir páginas de configuração
echo -e "${BLUE}🌐 Abrindo página de configuração para branch 'main'...${NC}"
xdg-open "https://github.com/$REPO/settings/branches" || open "https://github.com/$REPO/settings/branches" || echo "Não foi possível abrir o navegador automaticamente. Acesse: https://github.com/$REPO/settings/branches"

echo ""
echo -e "${YELLOW}📋 Instruções:${NC}"
echo "1. Clique em 'Add branch protection rule'"
echo "2. Em 'Branch name pattern', digite 'main'"
echo "3. Configure as proteções conforme recomendações acima"
echo "4. Clique em 'Create'"
echo "5. Repita o processo para a branch 'validar'"
echo ""
echo -e "${BLUE}🔗 Links diretos:${NC}"
echo "• Branch protection: https://github.com/$REPO/settings/branches"
echo "• Configurar CODEOWNERS: https://github.com/$REPO/new/main?filename=.github/CODEOWNERS"

echo ""
echo -e "${YELLOW}📝 Conteúdo recomendado para CODEOWNERS:${NC}"
echo "# FIAP-X Core Maintainers"
echo "* @hqmoraes"
echo ""
echo "# Auth Service"
echo "/auth-service/ @hqmoraes"
echo ""
echo "# Upload Service"
echo "/upload-service/ @hqmoraes"
echo ""
echo "# Processing Service"
echo "/processing-service/ @hqmoraes"
echo ""
echo "# Storage Service"
echo "/storage-service/ @hqmoraes"
echo ""
echo "# Frontend"
echo "/frontend/ @hqmoraes"
echo ""
echo "# Infrastructure"
echo "/infrastructure/ @hqmoraes"
echo "/k8s/ @hqmoraes"
echo ".github/workflows/ @hqmoraes"

echo ""
echo -e "${GREEN}✅ Para verificar o status atual das proteções, execute:${NC}"
echo "gh api repos/$REPO/branches/main/protection"
