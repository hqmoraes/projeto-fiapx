#!/bin/bash

# FIAP-X - Auto Setup Amazon SES
# Este script configura automaticamente o SES usando as credenciais do arquivo

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}    FIAP-X - Auto Setup Amazon SES       ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo

# Verificar se kubectl está configurado
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ kubectl não está configurado ou cluster não está acessível${NC}"
    exit 1
fi

# Verificar se namespace existe
if ! kubectl get namespace fiapx >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Namespace 'fiapx' não existe. Criando...${NC}"
    kubectl create namespace fiapx
fi

# Ler credenciais do arquivo
CREDENTIALS_FILE="temp/fiapx-error-notification_credentials.csv.backup"

if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo -e "${RED}❌ Arquivo de credenciais não encontrado: $CREDENTIALS_FILE${NC}"
    echo -e "${YELLOW}Execute: ./scripts/setup-ses-notifications.sh para configuração manual${NC}"
    exit 1
fi

echo -e "${BLUE}📖 Lendo credenciais do arquivo...${NC}"

# Extrair credenciais (ignorar primeira linha de cabeçalho e BOM)
SES_SMTP_USERNAME=$(tail -1 "$CREDENTIALS_FILE" | cut -d',' -f2 | tr -d '\r\n\ufeff')
SES_SMTP_PASSWORD=$(tail -1 "$CREDENTIALS_FILE" | cut -d',' -f3 | tr -d '\r\n\ufeff')

# Validar credenciais
if [[ -z "$SES_SMTP_USERNAME" || -z "$SES_SMTP_PASSWORD" ]]; then
    echo -e "${RED}❌ Não foi possível extrair credenciais do arquivo${NC}"
    echo -e "${YELLOW}Dados encontrados:${NC}"
    echo -e "Username: '$SES_SMTP_USERNAME'"
    echo -e "Password: '${SES_SMTP_PASSWORD:0:10}...'"
    exit 1
fi

echo -e "${GREEN}✅ Credenciais extraídas com sucesso${NC}"
echo -e "Username: $SES_SMTP_USERNAME"
echo -e "Password: ${SES_SMTP_PASSWORD:0:10}..."

# Deletar secret existente se existir
echo -e "${BLUE}🔐 Criando secret do Kubernetes para SES...${NC}"
kubectl delete secret ses-email-secrets -n fiapx 2>/dev/null || true

# Criar novo secret
kubectl create secret generic ses-email-secrets \
    --from-literal=ses-smtp-username="$SES_SMTP_USERNAME" \
    --from-literal=ses-smtp-password="$SES_SMTP_PASSWORD" \
    --namespace=fiapx

echo -e "${GREEN}✅ Secret SES criado com sucesso${NC}"

# Verificar se o deployment existe e atualizar
echo -e "${BLUE}📝 Atualizando deployment do notification-service...${NC}"

if kubectl get deployment notification-service -n fiapx >/dev/null 2>&1; then
    # Aplicar o manifest atualizado
    kubectl apply -f infrastructure/kubernetes/notification-service.yaml
    
    # Fazer restart do deployment para pegar as novas variáveis
    kubectl rollout restart deployment/notification-service -n fiapx
    
    echo -e "${GREEN}✅ Deployment atualizado e reiniciado${NC}"
    
    # Verificar status do deployment
    echo -e "${BLUE}📊 Verificando status do deployment...${NC}"
    kubectl rollout status deployment/notification-service -n fiapx --timeout=60s
    
else
    echo -e "${YELLOW}⚠️  Deployment notification-service não encontrado${NC}"
    echo -e "${YELLOW}   Aplicando manifest primeiro...${NC}"
    kubectl apply -f infrastructure/kubernetes/notification-service.yaml
    
    echo -e "${BLUE}📊 Aguardando deployment...${NC}"
    kubectl rollout status deployment/notification-service -n fiapx --timeout=60s
fi

# Verificar se o pod está rodando
echo -e "${BLUE}🔍 Verificando status do pod...${NC}"
kubectl get pods -n fiapx -l app=notification-service

# Verificar logs
echo -e "${BLUE}📋 Últimos logs do notification-service:${NC}"
kubectl logs -n fiapx -l app=notification-service --tail=10 || echo "Aguardando pod iniciar..."

echo
echo -e "${GREEN}✅ Configuração do Amazon SES concluída com sucesso!${NC}"
echo
echo -e "${BLUE}📋 Próximos passos:${NC}"
echo -e "1. Verificar se o notification-service está rodando:"
echo -e "   ${YELLOW}kubectl get pods -n fiapx -l app=notification-service${NC}"
echo
echo -e "2. Verificar logs:"
echo -e "   ${YELLOW}kubectl logs -n fiapx -l app=notification-service${NC}"
echo
echo -e "3. Testar envio de email:"
echo -e "   ${YELLOW}curl -X POST https://fiapx.wecando.click/notifications/send-email${NC}"
echo

# Limpar variáveis sensíveis
unset SES_SMTP_USERNAME
unset SES_SMTP_PASSWORD

echo -e "${GREEN}🔒 Credenciais removidas da memória${NC}"
