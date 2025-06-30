#!/bin/bash

# FIAP-X - Validação Completa do Projeto
# Este script valida se tudo está configurado corretamente

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}    FIAP-X - Validação Completa          ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo

TOTAL_CHECKS=0
PASSED_CHECKS=0

check_item() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-50s" "$description"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

check_content() {
    local description="$1"
    local file="$2"
    local pattern="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-50s" "$description"
    
    if [[ -f "$file" ]] && grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

echo -e "${BLUE}🔍 1. VERIFICAÇÃO DE SEGURANÇA${NC}"
echo "================================================="

check_item "Arquivo .gitignore principal protegido" "grep -q '*credentials*' .gitignore"
check_item "Auth service .gitignore protegido" "grep -q '*credentials*' auth-service/.gitignore"
check_item "Upload service .gitignore protegido" "grep -q '*credentials*' upload-service/.gitignore"
check_item "Processing service .gitignore protegido" "grep -q '*credentials*' processing-service/.gitignore"
check_item "Storage service .gitignore protegido" "grep -q '*credentials*' storage-service/.gitignore"
check_item "Frontend .gitignore protegido" "grep -q '*credentials*' frontend/.gitignore"

check_item "Credenciais SES em backup seguro" "[[ -f 'temp/fiapx-error-notification_credentials.csv.backup' ]]"
check_item "Credenciais SES NÃO em versão ativa" "[[ ! -f 'temp/fiapx-error-notification_credentials.csv' ]]"

echo
echo -e "${BLUE}🔧 2. VERIFICAÇÃO DE CI/CD${NC}"
echo "================================================="

for service in auth-service upload-service processing-service storage-service; do
    check_content "$service workflow atualizado" "$service/.github/workflows/ci.yml" "go-version: 1.21"
    check_content "$service security scan configurado" "$service/.github/workflows/ci.yml" "security-scan"
    check_content "$service test com env vars" "$service/.github/workflows/ci.yml" "JWT_SECRET:"
done

echo
echo -e "${BLUE}📧 3. VERIFICAÇÃO DO AMAZON SES${NC}"
echo "================================================="

check_content "Notification service configurado para SES" "notification-service/cmd/notification-service/main.go" "email-smtp.us-east-1.amazonaws.com"
check_content "Kubernetes manifest para SES" "infrastructure/kubernetes/notification-service.yaml" "ses-email-secrets"
check_content "Script auto-setup SES criado" "scripts/auto-setup-ses.sh" "SES_SMTP_USERNAME"

echo
echo -e "${BLUE}☁️ 4. VERIFICAÇÃO DO CLOUDFRONT${NC}"
echo "================================================="

check_content "CloudFront com origem separada" "infrastructure/https-cloudfront/cloudfront-distribution.yaml" "fiapx-frontend-origin"
check_content "CloudFront com cache behaviors" "infrastructure/https-cloudfront/cloudfront-distribution.yaml" "CacheBehaviors"
check_content "CloudFront com origem API" "infrastructure/https-cloudfront/cloudfront-distribution.yaml" "fiapx-api-origin"

echo
echo -e "${BLUE}🚀 5. VERIFICAÇÃO DE DEPLOY${NC}"
echo "================================================="

check_item "Script de deployment criado" "[[ -f 'deployment-commands.sh' && -x 'deployment-commands.sh' ]]"
check_item "Script de setup GitHub criado" "[[ -f 'scripts/setup-github-secrets.sh' && -x 'scripts/setup-github-secrets.sh' ]]"
check_item "Documentação de secrets criada" "[[ -f 'github-secrets-setup.md' ]]"
check_item "Template CI/CD criado" "[[ -f 'templates/ci-cd-template.yml' ]]"

echo
echo -e "${BLUE}📊 6. VERIFICAÇÃO DE ARQUIVOS .ENV.TEST${NC}"
echo "================================================="

for service in auth-service upload-service processing-service storage-service; do
    if [[ -f "$service/.env.test" ]]; then
        if grep -q "test-secret-key" "$service/.env.test" 2>/dev/null; then
            printf "%-50s" "$service .env.test seguro"
            echo -e "${RED}❌${NC}"
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        else
            printf "%-50s" "$service .env.test seguro"
            echo -e "${GREEN}✅${NC}"
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    fi
done

echo
echo "================================================="
echo -e "${BLUE}📈 RESULTADO DA VALIDAÇÃO${NC}"
echo "================================================="

PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo -e "Total de verificações: ${BLUE}$TOTAL_CHECKS${NC}"
echo -e "Verificações aprovadas: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Verificações falharam: ${RED}$((TOTAL_CHECKS - PASSED_CHECKS))${NC}"
echo -e "Percentual de sucesso: ${BLUE}$PERCENTAGE%${NC}"

echo
if [[ $PERCENTAGE -ge 90 ]]; then
    echo -e "${GREEN}🎉 EXCELENTE! Projeto pronto para produção!${NC}"
elif [[ $PERCENTAGE -ge 75 ]]; then
    echo -e "${YELLOW}⚠️  BOM! Algumas correções menores necessárias.${NC}"
else
    echo -e "${RED}❌ ATENÇÃO! Correções importantes necessárias.${NC}"
fi

echo
echo -e "${BLUE}📋 PRÓXIMOS PASSOS RECOMENDADOS:${NC}"

if command -v gh &> /dev/null; then
    echo -e "1. ${YELLOW}./scripts/setup-github-secrets.sh${NC} - Configurar secrets do GitHub"
else
    echo -e "1. ${YELLOW}Instalar GitHub CLI${NC} e configurar secrets manualmente"
fi

if command -v kubectl &> /dev/null; then
    echo -e "2. ${YELLOW}./deployment-commands.sh${NC} - Executar deployment completo"
else
    echo -e "2. ${YELLOW}Conectar ao cluster K8s${NC} e executar deployment"
fi

echo -e "3. ${YELLOW}Testar aplicação${NC} com HTTPS end-to-end"
echo -e "4. ${YELLOW}Monitorar pipelines CI/CD${NC} na branch 'validar'"

echo
echo -e "${GREEN}✅ Validação completa finalizada!${NC}"
