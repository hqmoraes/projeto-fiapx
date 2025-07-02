#!/bin/bash
# 🚨 Script de Limpeza de Segurança - Remove credenciais expostas

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🚨 LIMPEZA DE SEGURANÇA - CREDENCIAIS EXPOSTAS${NC}"
echo ""

# Verificar se estamos em um repositório Git
if [[ ! -d .git ]]; then
    echo -e "${RED}❌ Este não é um repositório Git${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  Este script irá:${NC}"
echo "1. Remover arquivos com credenciais expostas"
echo "2. Criar templates seguros"
echo "3. Atualizar .gitignore"
echo ""

read -p "Continuar? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "Operação cancelada"
    exit 0
fi

echo ""
echo -e "${BLUE}🧹 Removendo arquivos sensíveis...${NC}"

# Remover arquivo com credenciais AWS
if [[ -f "temp/fiapx-error-notification_credentials.csv.backup" ]]; then
    echo "Removendo credenciais AWS expostas..."
    git rm temp/fiapx-error-notification_credentials.csv.backup 2>/dev/null || rm -f temp/fiapx-error-notification_credentials.csv.backup
fi

# Criar template para secrets Kubernetes
echo -e "${BLUE}📝 Criando templates seguros...${NC}"

mkdir -p infrastructure/kubernetes/auth-service

cat > infrastructure/kubernetes/auth-service/auth-secret-template.yaml << 'EOF'
# Template para auth-secret.yaml
# NÃO commite este arquivo com valores reais!
apiVersion: v1
kind: Secret
metadata:
  name: auth-secret
type: Opaque
stringData:
  jwt-secret: "SUBSTITUA-POR-JWT-SECRET-REAL-VIA-GITHUB-SECRETS"
EOF

# Atualizar o arquivo atual para usar template
if [[ -f "infrastructure/kubernetes/auth-service/auth-secret.yaml" ]]; then
    echo "Atualizando auth-secret.yaml para usar template..."
    cp infrastructure/kubernetes/auth-service/auth-secret-template.yaml infrastructure/kubernetes/auth-service/auth-secret.yaml
fi

# Garantir que está no .gitignore
echo -e "${BLUE}🔒 Atualizando .gitignore...${NC}"

# Adicionar regras específicas para os arquivos encontrados
cat >> .gitignore << 'EOF'

# Arquivos de credenciais específicos encontrados
temp/*credentials*.csv*
temp/*credentials*.backup
infrastructure/kubernetes/*/auth-secret.yaml
!infrastructure/kubernetes/*/auth-secret-template.yaml

EOF

echo -e "${GREEN}✅ Limpeza concluída!${NC}"
echo ""

echo -e "${YELLOW}🔐 Próximos passos OBRIGATÓRIOS:${NC}"
echo ""
echo "1. REVOGUE IMEDIATAMENTE as credenciais AWS SES:"
echo "   - Username: AKIA2CEKWSP6M2BNI4BU"
echo "   - Acesse: https://console.aws.amazon.com/iam/home#/users/fiapx-error-notification"
echo ""
echo "2. Crie novas credenciais AWS SES"
echo ""
echo "3. Configure as novas credenciais como GitHub Secrets:"
echo "   gh secret set AWS_ACCESS_KEY_ID -b 'NOVA_ACCESS_KEY' -R hqmoraes/projeto-fiapx"
echo "   gh secret set AWS_SECRET_ACCESS_KEY -b 'NOVA_SECRET_KEY' -R hqmoraes/projeto-fiapx"
echo ""
echo "4. Commite as mudanças:"
echo "   git add ."
echo "   git commit -m 'security: remove exposed credentials and add templates'"
echo "   git push"
echo ""

echo -e "${RED}⚠️  IMPORTANTE:${NC}"
echo "• Monitore logs AWS por atividade suspeita"
echo "• Considere notificar a equipe de segurança"
echo "• Revise outros repositórios por exposições similares"

echo ""
echo -e "${BLUE}📊 Verificando outros possíveis arquivos sensíveis...${NC}"

# Buscar por outros padrões suspeitos
suspicious_files=$(find . -type f \( -name "*.key" -o -name "*.pem" -o -name "*secret*" -o -name "*credential*" -o -name "*token*" \) ! -path "./.git/*" ! -name "check-github-secrets.sh" ! -name "setup-github-secrets.sh" ! -name "*template*" ! -name "*.md" 2>/dev/null | head -10)

if [[ -n "$suspicious_files" ]]; then
    echo -e "${YELLOW}⚠️  Arquivos suspeitos encontrados:${NC}"
    echo "$suspicious_files"
    echo ""
    echo "Revise estes arquivos manualmente!"
else
    echo -e "${GREEN}✅ Nenhum arquivo suspeito adicional encontrado${NC}"
fi
