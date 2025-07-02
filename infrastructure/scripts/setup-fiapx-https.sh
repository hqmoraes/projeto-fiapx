#!/bin/bash

# Script para configurar DNS Route53 para fiapx.wecando.click
# Aponta o domínio para o cluster Kubernetes com HTTPS

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🚀 FIAP-X: Configuração HTTPS para fiapx.wecando.click"
echo "=================================================="

# Configurações
DOMAIN="wecando.click"
SUBDOMAIN="fiapx.wecando.click"
CLUSTER_IP="107.23.149.199"  # IP público do cluster
SSH_KEY="~/.ssh/keyPrincipal.pem"
SSH_USER="ubuntu"
SSH_HOST="worker.wecando.click"

# Função para executar comandos via SSH
run_ssh() {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST "$1"
}

log "📡 Verificando conectividade com o cluster via SSH..."
if ! run_ssh "echo 'SSH connection successful'" >/dev/null 2>&1; then
    error "Não foi possível conectar ao cluster via SSH: $SSH_HOST"
    exit 1
fi

log "✅ Cluster acessível via SSH: $SSH_HOST"

# Obter Zone ID do Route53
log "🌐 Obtendo Zone ID do Route53 para $DOMAIN..."
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.'].Id" --output text)

if [ -z "$ZONE_ID" ]; then
    error "Zone não encontrada para $DOMAIN"
    exit 1
fi

# Remover prefix /hostedzone/ se presente
ZONE_ID=${ZONE_ID##*/}

log "✅ Zone ID encontrado: $ZONE_ID"

# Verificar se o record já existe
log "🔍 Verificando se $SUBDOMAIN já existe..."
EXISTING_RECORD=$(aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --query "ResourceRecordSets[?Name=='${SUBDOMAIN}.']" --output text)

if [ ! -z "$EXISTING_RECORD" ]; then
    warn "⚠️ Record $SUBDOMAIN já existe. Será atualizado."
fi

# Criar/Atualizar record DNS
log "📝 Configurando DNS A record para $SUBDOMAIN → $CLUSTER_IP..."

cat > /tmp/dns-record.json << EOF
{
  "Comment": "FIAP-X Frontend HTTPS - fiapx.wecando.click",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$SUBDOMAIN",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$CLUSTER_IP"
          }
        ]
      }
    }
  ]
}
EOF

# Aplicar mudança DNS
CHANGE_ID=$(aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file:///tmp/dns-record.json --query 'ChangeInfo.Id' --output text)

log "✅ DNS change criado: $CHANGE_ID"

# Aguardar propagação DNS
log "⏳ Aguardando propagação DNS (pode levar alguns minutos)..."
aws route53 wait resource-record-sets-changed --id $CHANGE_ID

log "✅ DNS propagado com sucesso!"

# Verificar resolução DNS
log "🔍 Testando resolução DNS..."
for i in {1..10}; do
    if nslookup $SUBDOMAIN >/dev/null 2>&1; then
        RESOLVED_IP=$(nslookup $SUBDOMAIN | grep -A1 "Name:" | tail -1 | awk '{print $2}')
        if [ "$RESOLVED_IP" = "$CLUSTER_IP" ]; then
            log "✅ DNS resolvendo corretamente: $SUBDOMAIN → $RESOLVED_IP"
            break
        fi
    fi
    echo -n "."
    sleep 5
done

# Atualizar certificado SSL para incluir fiapx.wecando.click
log "🔒 Atualizando certificado SSL via SSH..."

run_ssh "kubectl get certificate fiapx-tls-secret -n fiapx -o yaml" > /tmp/current-cert.yaml 2>/dev/null || {
    warn "Certificado não encontrado. Será criado novo certificado."
}

# Criar certificado atualizado
cat > /tmp/fiapx-certificate.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: fiapx-tls-secret
  namespace: fiapx
spec:
  secretName: fiapx-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - api.wecando.click
  - fiapx.wecando.click
  - auth.wecando.click
  - upload.wecando.click
  - processing.wecando.click
  - storage.wecando.click
EOF

# Copiar para o servidor e aplicar
scp -i $SSH_KEY -o StrictHostKeyChecking=no /tmp/fiapx-certificate.yaml $SSH_USER@$SSH_HOST:/tmp/

log "📜 Aplicando certificado SSL atualizado..."
run_ssh "kubectl apply -f /tmp/fiapx-certificate.yaml"

# Aguardar certificado ser gerado
log "⏳ Aguardando geração do certificado SSL (pode levar alguns minutos)..."
for i in {1..30}; do
    if run_ssh "kubectl get certificate fiapx-tls-secret -n fiapx -o jsonpath='{.status.conditions[0].status}'" | grep -q "True"; then
        log "✅ Certificado SSL gerado com sucesso!"
        break
    fi
    echo -n "."
    sleep 10
done

# Aplicar Ingress atualizado
log "🌐 Aplicando configuração do Ingress..."
scp -i $SSH_KEY -o StrictHostKeyChecking=no ./infrastructure/kubernetes/ingress/fiapx-ingress.yaml $SSH_USER@$SSH_HOST:/tmp/

run_ssh "kubectl apply -f /tmp/fiapx-ingress.yaml"

# Aguardar Ingress ser configurado
log "⏳ Aguardando configuração do Ingress..."
sleep 10

# Verificar status do Ingress
log "📊 Status do Ingress:"
run_ssh "kubectl get ingress fiapx-ingress -n fiapx"

# Testar endpoints
log "🧪 Testando endpoints HTTPS..."

echo ""
log "🌐 Frontend:"
echo "   https://$SUBDOMAIN"

echo ""
log "🔧 API Endpoints:"
echo "   https://api.wecando.click/auth/health"
echo "   https://api.wecando.click/upload/health"
echo "   https://api.wecando.click/processing/health"
echo "   https://api.wecando.click/storage/health"

# Teste básico de conectividade
echo ""
log "🔍 Teste de conectividade:"

# Testar frontend
if curl -k -I "https://$SUBDOMAIN" 2>/dev/null | grep -q "200\|301\|302"; then
    log "✅ Frontend acessível: https://$SUBDOMAIN"
else
    warn "⚠️ Frontend pode ainda estar propagando. Teste em alguns minutos."
fi

# Testar API
if curl -k -I "https://api.wecando.click/auth/health" 2>/dev/null | grep -q "200\|404"; then
    log "✅ API acessível: https://api.wecando.click"
else
    warn "⚠️ API pode ainda estar propagando. Teste em alguns minutos."
fi

# Cleanup
rm -f /tmp/dns-record.json /tmp/fiapx-certificate.yaml /tmp/current-cert.yaml

echo ""
log "🎉 Configuração HTTPS concluída com sucesso!"
echo ""
log "📋 Resumo:"
log "   🌐 Frontend: https://$SUBDOMAIN"
log "   🔧 API: https://api.wecando.click"
log "   🔒 SSL: Let's Encrypt automático"
log "   📡 DNS: Route53 configurado"
echo ""
log "⚠️ Aguarde alguns minutos para propagação completa do DNS e SSL"
log "📝 Próximo passo: Atualizar frontend para usar URLs HTTPS"

echo ""
log "✅ FIAP-X HTTPS setup completo!"
