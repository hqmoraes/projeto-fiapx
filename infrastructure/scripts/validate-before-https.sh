#!/bin/bash

# Script de validação pré-deploy HTTPS
# FIAP X - Verificações antes da execução

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "🔍 FIAP X - Validação Pré-Deploy HTTPS"
echo "======================================"

ERRORS=0

# 1. Verificar AWS CLI
echo ""
echo "1. Verificando AWS CLI..."
if command -v aws &> /dev/null; then
    log "AWS CLI instalado"
    if aws sts get-caller-identity &> /dev/null; then
        log "Credenciais AWS válidas"
        ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        log "Account: $ACCOUNT"
    else
        error "Credenciais AWS inválidas"
        ERRORS=$((ERRORS + 1))
    fi
else
    error "AWS CLI não encontrado"
    ERRORS=$((ERRORS + 1))
fi

# 2. Verificar domínio no Route53
echo ""
echo "2. Verificando domínio wecando.click no Route53..."
if aws route53 list-hosted-zones-by-name --dns-name wecando.click --query 'HostedZones[0].Name' --output text 2>/dev/null | grep -q "wecando.click"; then
    log "Domínio wecando.click encontrado no Route53"
    ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name wecando.click --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)
    log "Zone ID: $ZONE_ID"
else
    error "Domínio wecando.click não encontrado no Route53"
    ERRORS=$((ERRORS + 1))
fi

# 3. Verificar chave SSH
echo ""
echo "3. Verificando chave SSH..."
SSH_KEY="$HOME/.ssh/keyPrincipal.pem"
if [ -f "$SSH_KEY" ]; then
    log "Chave SSH encontrada: $SSH_KEY"
    if [ -r "$SSH_KEY" ]; then
        log "Chave SSH legível"
        # Verificar permissões
        PERMS=$(stat -c "%a" "$SSH_KEY")
        if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
            log "Permissões da chave corretas ($PERMS)"
        else
            warn "Permissões da chave ($PERMS) - recomendado 600"
            echo "   Execute: chmod 600 $SSH_KEY"
        fi
    else
        error "Chave SSH não legível"
        ERRORS=$((ERRORS + 1))
    fi
else
    error "Chave SSH não encontrada: $SSH_KEY"
    ERRORS=$((ERRORS + 1))
fi

# 4. Verificar conectividade SSH
echo ""
echo "4. Testando conectividade SSH..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@worker.wecando.click "echo 'SSH OK'" 2>/dev/null; then
    log "Conectividade SSH funcionando"
else
    error "Falha na conectividade SSH para worker.wecando.click"
    ERRORS=$((ERRORS + 1))
fi

# 5. Verificar cluster Kubernetes
echo ""
echo "5. Verificando cluster Kubernetes..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@worker.wecando.click "kubectl get nodes --no-headers 2>/dev/null | wc -l" 2>/dev/null | grep -q -E "[1-9]"; then
    log "Cluster Kubernetes acessível"
    NODES=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@worker.wecando.click "kubectl get nodes --no-headers 2>/dev/null | wc -l" 2>/dev/null)
    log "Nodes encontrados: $NODES"
else
    error "Cluster Kubernetes não acessível"
    ERRORS=$((ERRORS + 1))
fi

# 6. Verificar microsserviços
echo ""
echo "6. Verificando microsserviços..."
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")
for service in "${SERVICES[@]}"; do
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@worker.wecando.click "kubectl get service $service -n fiapx --no-headers 2>/dev/null" &>/dev/null; then
        log "Serviço $service encontrado"
    else
        error "Serviço $service não encontrado"
        ERRORS=$((ERRORS + 1))
    fi
done

# 7. Verificar aplicação Amplify
echo ""
echo "7. Verificando aplicação AWS Amplify..."
if aws amplify get-app --app-id d13ms2nooclzwx --region us-east-1 &>/dev/null; then
    log "Aplicação Amplify encontrada"
    APP_NAME=$(aws amplify get-app --app-id d13ms2nooclzwx --region us-east-1 --query 'app.name' --output text)
    log "Nome: $APP_NAME"
else
    error "Aplicação Amplify não encontrada"
    ERRORS=$((ERRORS + 1))
fi

# 8. Verificar arquivos necessários
echo ""
echo "8. Verificando arquivos do projeto..."
FILES=("frontend/index.html" "frontend/config.js" "frontend/auth.js" "frontend/api.js")
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        log "Arquivo encontrado: $file"
    else
        error "Arquivo não encontrado: $file"
        ERRORS=$((ERRORS + 1))
    fi
done

# Resumo
echo ""
echo "======================================"
if [ $ERRORS -eq 0 ]; then
    log "✅ TODAS as verificações passaram!"
    echo ""
    log "🚀 Sistema pronto para deploy HTTPS"
    echo ""
    echo "Execute na ordem:"
    echo "1. ./infrastructure/scripts/setup-https-cluster.sh"
    echo "2. ./infrastructure/scripts/deploy-frontend-https.sh"
else
    error "❌ $ERRORS erro(s) encontrado(s)"
    echo ""
    error "Corrija os problemas acima antes de continuar"
    exit 1
fi

echo ""
echo "📋 O que será implementado:"
echo "   🔑 cert-manager (ARM64) para certificados SSL"
echo "   🌐 nginx-ingress (ARM64) para proxy HTTPS"
echo "   🗺️ DNS Route53 para subdomínios *.wecando.click"
echo "   🔒 Let's Encrypt SSL (gratuito)"
echo "   📤 Frontend atualizado com URLs HTTPS"
echo ""
echo "💰 Custo estimado: < $1/mês (apenas Route53)"
echo "⚡ Tempo estimado: 10-15 minutos"
echo ""
log "Pronto para resolver o Mixed Content! 🎉"
