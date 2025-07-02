#!/bin/bash

# FIAP-X - Setup Amazon SES Email Notifications
# Este script configura o Amazon SES para envio de emails de notificação
# Usa credenciais seguras via Kubernetes Secrets

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}    FIAP-X - Setup Amazon SES Email      ${NC}"
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

echo -e "${YELLOW}🔐 Configuração de Credenciais AWS SES${NC}"
echo -e "${YELLOW}IMPORTANTE: Nunca commite credenciais no código!${NC}"
echo

# Solicitar credenciais do usuário
echo -e "${BLUE}Insira as credenciais AWS SES:${NC}"
echo -e "${YELLOW}Nota: Essas credenciais devem vir do arquivo fornecido separadamente${NC}"
echo

read -p "AWS SES SMTP Username: " SES_SMTP_USERNAME
read -s -p "AWS SES SMTP Password: " SES_SMTP_PASSWORD
echo

# Validar entrada
if [[ -z "$SES_SMTP_USERNAME" || -z "$SES_SMTP_PASSWORD" ]]; then
    echo -e "${RED}❌ Credenciais não podem estar vazias${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Credenciais fornecidas${NC}"

# Criar ou atualizar secret do Kubernetes
echo -e "${BLUE}🔐 Criando secret do Kubernetes para SES...${NC}"

# Deletar secret existente se existir
kubectl delete secret ses-email-secrets -n fiapx 2>/dev/null || true

# Criar novo secret
kubectl create secret generic ses-email-secrets \
    --from-literal=ses-smtp-username="$SES_SMTP_USERNAME" \
    --from-literal=ses-smtp-password="$SES_SMTP_PASSWORD" \
    --namespace=fiapx

echo -e "${GREEN}✅ Secret SES criado com sucesso${NC}"

# Atualizar deployment do notification-service
echo -e "${BLUE}📝 Atualizando deployment do notification-service...${NC}"

# Verificar se o deployment existe
if kubectl get deployment notification-service -n fiapx >/dev/null 2>&1; then
    # Atualizar deployment existente
    kubectl patch deployment notification-service -n fiapx --patch='
spec:
  template:
    spec:
      containers:
      - name: notification-service
        env:
        - name: SMTP_HOST
          value: "email-smtp.us-east-1.amazonaws.com"
        - name: SMTP_PORT
          value: "587"
        - name: SMTP_USERNAME
          valueFrom:
            secretKeyRef:
              name: ses-email-secrets
              key: ses-smtp-username
        - name: SMTP_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ses-email-secrets
              key: ses-smtp-password
        - name: FROM_EMAIL
          value: "noreply@fiapx.wecando.click"
        - name: FROM_NAME
          value: "FIAP-X Video Processing"
    '
    echo -e "${GREEN}✅ Deployment atualizado${NC}"
else
    echo -e "${YELLOW}⚠️  Deployment notification-service não encontrado${NC}"
    echo -e "${YELLOW}   Aplique o manifest primeiro: kubectl apply -f infrastructure/kubernetes/notification-service.yaml${NC}"
fi

# Verificar status do deployment
echo -e "${BLUE}📊 Verificando status do deployment...${NC}"
kubectl rollout status deployment/notification-service -n fiapx --timeout=60s

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
echo -e "3. Testar envio de email via API:"
echo -e "   ${YELLOW}curl -X POST https://fiapx.wecando.click/notifications/send-email${NC}"
echo

# Limpar variáveis sensíveis
unset SES_SMTP_USERNAME
unset SES_SMTP_PASSWORD

echo -e "${GREEN}🔒 Credenciais removidas da memória${NC}"
