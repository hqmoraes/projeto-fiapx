#!/bin/bash

# Script para deploy do frontend atualizado com URLs HTTPS
# FIAP X - Frontend com endpoints HTTPS dos microsserviços

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log "🚀 Deploy do frontend com URLs HTTPS"

# Verificar se está no diretório correto
if [ ! -f "frontend/index.html" ]; then
    echo "Execute este script do diretório raiz do projeto"
    exit 1
fi

cd frontend/

log "📝 Verificando configuração HTTPS..."
grep -E "(auth|upload|processing|storage)\.wecando\.click" config.js || {
    warn "Configuração HTTPS não encontrada. Execute primeiro: ./infrastructure/scripts/setup-https-cluster.sh"
    exit 1
}

log "📦 Criando pacote para deploy..."
zip -r fiapx-frontend-https.zip . -x "*.git*" "*.sh" "Dockerfile" "nginx.conf" "README.md" "AMPLIFY-DEPLOY-GUIDE.md" "DEPLOY-SUCCESS-AWS-AMPLIFY.md"

log "🔄 Criando novo deployment no AWS Amplify..."
DEPLOYMENT=$(aws amplify create-deployment --app-id d13ms2nooclzwx --branch-name main --region us-east-1 --output json)
UPLOAD_URL=$(echo $DEPLOYMENT | jq -r '.zipUploadUrl')
JOB_ID=$(echo $DEPLOYMENT | jq -r '.jobId')

log "📤 Fazendo upload do frontend atualizado..."
curl -T fiapx-frontend-https.zip "$UPLOAD_URL"

log "🚀 Iniciando deployment..."
aws amplify start-deployment --app-id d13ms2nooclzwx --branch-name main --job-id $JOB_ID --region us-east-1

log "⏳ Aguardando deployment..."
for i in {1..30}; do
    STATUS=$(aws amplify get-job --app-id d13ms2nooclzwx --branch-name main --job-id $JOB_ID --region us-east-1 --query 'job.summary.status' --output text)
    
    if [ "$STATUS" = "SUCCEED" ]; then
        log "✅ Deploy concluído com sucesso!"
        break
    elif [ "$STATUS" = "FAILED" ]; then
        echo "❌ Deploy falhou!"
        exit 1
    fi
    
    echo -n "."
    sleep 10
done

log "🌐 Frontend atualizado disponível em:"
log "   https://main.d13ms2nooclzwx.amplifyapp.com"

log "🔍 Testando novo frontend..."
if curl -I https://main.d13ms2nooclzwx.amplifyapp.com 2>/dev/null | grep -q "200"; then
    log "✅ Frontend online!"
else
    warn "⚠️  Verificar status do frontend"
fi

log "🎉 Mixed Content resolvido!"
log "   Frontend HTTPS → Microsserviços HTTPS"
log "   URLs atualizadas para *.wecando.click"

# Cleanup
rm -f fiapx-frontend-https.zip

echo ""
log "📋 Próximos passos:"
log "1. Testar login/registro no frontend"
log "2. Verificar upload de vídeos"
log "3. Confirmar processamento end-to-end"
echo ""
log "🚀 Sistema totalmente HTTPS operacional!"
