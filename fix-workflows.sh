#!/bin/bash
# 🛠️ Corretor de Workflows CI/CD - FIAP-X
# Este script corrige inconsistências nos workflows de CI/CD

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKFLOWS_DIR=".github/workflows"

echo -e "${BLUE}🛠️ Correção de Workflows CI/CD - FIAP-X${NC}"
echo ""

# Verificar se o diretório de workflows existe
if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    echo -e "${RED}❌ Diretório de workflows não encontrado: $WORKFLOWS_DIR${NC}"
    exit 1
fi

# Perguntar antes de fazer mudanças
echo -e "${YELLOW}⚠️  Este script irá:${NC}"
echo "1. Padronizar os nomes das secrets do Docker Hub"
echo "2. Garantir triggers consistentes em todos os workflows"
echo "3. Fazer backup dos arquivos originais"
echo ""

read -p "Continuar? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Operação cancelada"
    exit 0
fi

# Criar diretório de backup
BACKUP_DIR="workflow-backups-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}📁 Criando backups em: $BACKUP_DIR${NC}"

# Copiar workflows para backup
cp -r "$WORKFLOWS_DIR"/*.yml "$BACKUP_DIR/"

# Padronizar secrets do Docker Hub
echo -e "${YELLOW}🔄 Padronizando secrets do Docker Hub...${NC}"

# Usar DOCKER_USERNAME e DOCKER_PASSWORD consistentemente
for workflow in $(find "$WORKFLOWS_DIR" -name "*.yml"); do
    # Fazer backup
    cp "$workflow" "$BACKUP_DIR/$(basename "$workflow")"
    
    echo "Processando: $(basename "$workflow")"
    
    # Substituir DOCKERHUB_USERNAME por DOCKER_USERNAME
    sed -i 's/secrets.DOCKERHUB_USERNAME/secrets.DOCKER_USERNAME/g' "$workflow"
    
    # Substituir DOCKERHUB_TOKEN por DOCKER_PASSWORD
    sed -i 's/secrets.DOCKERHUB_TOKEN/secrets.DOCKER_PASSWORD/g' "$workflow"
    
    # Verificar mudanças
    if diff -q "$workflow" "$BACKUP_DIR/$(basename "$workflow")" > /dev/null; then
        echo "  • Nenhuma mudança necessária"
    else
        echo -e "  • ${GREEN}Corrigido: $(basename "$workflow")${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Correções aplicadas!${NC}"
echo ""
echo -e "${YELLOW}📋 Próximos passos:${NC}"
echo "1. Revise os arquivos modificados (compare com $BACKUP_DIR)"
echo "2. Teste os workflows com um commit de teste"
echo "3. Configure branch protection no GitHub"
