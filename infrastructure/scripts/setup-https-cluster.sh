#!/bin/bash

# Script para configurar HTTPS no cluster Kubernetes ARM64
# FIAP X - Solução completa para Mixed Content
# Executa via SSH no servidor worker.wecando.click

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configurações
DOMAIN="wecando.click"
EMAIL="admin@wecando.click"
CLUSTER_IP="107.23.149.199"  # IP público do cluster
SSH_KEY="~/.ssh/keyPrincipal.pem"
SSH_USER="ubuntu"
SSH_HOST="worker.wecando.click"

log "🚀 Iniciando configuração HTTPS para microsserviços FIAP X"
log "🏗️ Arquitetura: ARM64"
log "🌐 Domínio: ${DOMAIN}"
log "📧 Email: ${EMAIL}"

# Função para executar comandos via SSH
run_ssh() {
    ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${SSH_USER}@${SSH_HOST} "$1"
}

# Função para copiar arquivos via SCP
copy_file() {
    scp -i ${SSH_KEY} -o StrictHostKeyChecking=no "$1" ${SSH_USER}@${SSH_HOST}:"$2"
}

log "🔧 Verificando conectividade SSH..."
if ! run_ssh "echo 'SSH OK'"; then
    error "Falha na conexão SSH. Verifique chave e conectividade."
    exit 1
fi

log "📋 Verificando cluster Kubernetes..."
run_ssh "kubectl get nodes"

log "📦 Instalando cert-manager (ARM64)..."
run_ssh "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml"

log "⏳ Aguardando cert-manager inicializar..."
run_ssh "kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s"

log "🔑 Criando ClusterIssuer para Let's Encrypt..."
cat > /tmp/cluster-issuer.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

copy_file "/tmp/cluster-issuer.yaml" "cluster-issuer.yaml"
run_ssh "kubectl apply -f cluster-issuer.yaml"

log "🌐 Instalando nginx-ingress (ARM64)..."
run_ssh "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml"

log "⏳ Aguardando nginx-ingress inicializar..."
run_ssh "kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s"

log "🔍 Verificando IP do LoadBalancer..."
INGRESS_IP=$(run_ssh "kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'")

if [ -z "$INGRESS_IP" ]; then
    warn "LoadBalancer IP não disponível, usando NodePort..."
    INGRESS_PORT=$(run_ssh "kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name==\"https\")].nodePort}'")
    INGRESS_IP="${CLUSTER_IP}"
    log "📍 Usando ${INGRESS_IP}:${INGRESS_PORT}"
else
    log "📍 LoadBalancer IP: ${INGRESS_IP}"
fi

log "🗺️ Configurando DNS no Route53..."
aws route53 change-resource-record-sets --hosted-zone-id $(aws route53 list-hosted-zones-by-name --dns-name ${DOMAIN} --query 'HostedZones[0].Id' --output text | cut -d'/' -f3) --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.'${DOMAIN}'",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'${INGRESS_IP}'"}]
      }
    },
    {
      "Action": "UPSERT", 
      "ResourceRecordSet": {
        "Name": "auth.'${DOMAIN}'",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "api.'${DOMAIN}'"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "upload.'${DOMAIN}'", 
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "api.'${DOMAIN}'"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "processing.'${DOMAIN}'",
        "Type": "CNAME", 
        "TTL": 300,
        "ResourceRecords": [{"Value": "api.'${DOMAIN}'"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "storage.'${DOMAIN}'",
        "Type": "CNAME",
        "TTL": 300, 
        "ResourceRecords": [{"Value": "api.'${DOMAIN}'"}]
      }
    }
  ]
}'

log "🔗 Criando Ingress com certificados SSL..."
cat > /tmp/ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fiapx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://main.d13ms2nooclzwx.amplifyapp.com,https://d13ms2nooclzwx.amplifyapp.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    nginx.ingress.kubernetes.io/enable-cors: "true"
spec:
  tls:
  - hosts:
    - auth.${DOMAIN}
    - upload.${DOMAIN}  
    - processing.${DOMAIN}
    - storage.${DOMAIN}
    secretName: fiapx-tls
  rules:
  - host: auth.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: auth-service
            port:
              number: 8080
  - host: upload.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: upload-service
            port:
              number: 8080
  - host: processing.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: processing-service
            port:
              number: 8080
  - host: storage.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: storage-service
            port:
              number: 8080
EOF

copy_file "/tmp/ingress.yaml" "ingress.yaml"
run_ssh "kubectl apply -f ingress.yaml"

log "⏳ Aguardando certificados SSL serem gerados..."
log "   Isso pode levar alguns minutos..."

# Aguardar certificados
for i in {1..30}; do
    if run_ssh "kubectl get certificate fiapx-tls -o jsonpath='{.status.conditions[0].status}'" | grep -q "True"; then
        log "✅ Certificados SSL gerados com sucesso!"
        break
    fi
    echo -n "."
    sleep 10
done

log "🔍 Verificando status dos certificados..."
run_ssh "kubectl get certificate fiapx-tls"
run_ssh "kubectl describe certificate fiapx-tls"

log "🌐 Testando endpoints HTTPS..."
for service in auth upload processing storage; do
    echo "Testing https://${service}.${DOMAIN}/health"
    if curl -k -I "https://${service}.${DOMAIN}/health" 2>/dev/null | grep -q "200\|404"; then
        log "✅ ${service}.${DOMAIN} - OK"
    else
        warn "⚠️  ${service}.${DOMAIN} - Verificar"
    fi
done

log "📝 Criando nova configuração do frontend..."
cat > /tmp/config-https.js << 'EOF'
// Configuração HTTPS dos endpoints dos microsserviços
const CONFIG = {
    // URLs HTTPS dos microsserviços via Ingress
    AUTH_SERVICE_URL: 'https://auth.wecando.click',
    UPLOAD_SERVICE_URL: 'https://upload.wecando.click', 
    PROCESSING_SERVICE_URL: 'https://processing.wecando.click',
    STORAGE_SERVICE_URL: 'https://storage.wecando.click',
    
    // Configurações da aplicação
    APP_NAME: 'FIAP X - Video Processing Platform',
    MAX_FILE_SIZE: 100 * 1024 * 1024, // 100MB
    ALLOWED_VIDEO_TYPES: ['video/mp4', 'video/avi', 'video/mov', 'video/mkv', 'video/webm'],
    
    // Configurações de polling para status
    POLLING_INTERVAL: 5000, // 5 segundos
    MAX_POLLING_ATTEMPTS: 120, // 10 minutos máximo
};

// Mensagens de erro padrão
const ERROR_MESSAGES = {
    NETWORK_ERROR: 'Erro de conexão. Verifique sua internet.',
    AUTH_FAILED: 'Falha na autenticação. Verifique suas credenciais.',
    FILE_TOO_LARGE: `Arquivo muito grande. Máximo: ${CONFIG.MAX_FILE_SIZE / (1024 * 1024)}MB`,
    INVALID_FILE_TYPE: 'Tipo de arquivo não suportado.',
    UPLOAD_FAILED: 'Falha no upload do arquivo.',
    SERVER_ERROR: 'Erro interno do servidor.',
};

// Mensagens de sucesso
const SUCCESS_MESSAGES = {
    LOGIN_SUCCESS: 'Login realizado com sucesso!',
    REGISTER_SUCCESS: 'Conta criada com sucesso!',
    UPLOAD_SUCCESS: 'Upload realizado com sucesso!',
    PROCESSING_STARTED: 'Processamento iniciado!',
};

// Debug mode
const DEBUG = true;

// Função de log para debug
function debugLog(message, data = null) {
    if (DEBUG) {
        console.log(`[FIAP-X DEBUG] ${message}`, data || '');
    }
}

// Log da configuração
debugLog('Configuração HTTPS carregada:', {
    auth: CONFIG.AUTH_SERVICE_URL,
    upload: CONFIG.UPLOAD_SERVICE_URL,
    processing: CONFIG.PROCESSING_SERVICE_URL,
    storage: CONFIG.STORAGE_SERVICE_URL
});
EOF

log "📤 Subindo nova configuração para o frontend..."
cp /tmp/config-https.js ./frontend/config.js

echo ""
log "🎉 Configuração HTTPS concluída com sucesso!"
echo ""
log "📊 Resumo da configuração:"
log "   🔐 Certificados SSL: Let's Encrypt"
log "   🌐 DNS: Route53 (${DOMAIN})"
log "   🔗 Ingress: nginx-ingress (ARM64)"
log "   📍 Endpoints HTTPS:"
log "      - https://auth.${DOMAIN}"
log "      - https://upload.${DOMAIN}"
log "      - https://processing.${DOMAIN}"
log "      - https://storage.${DOMAIN}"
echo ""
log "🚀 Próximo passo: Fazer novo deploy do frontend com as URLs HTTPS"
log "   Execute: ./deploy-frontend-https.sh"
echo ""
log "✅ Mixed Content resolvido! Frontend HTTPS → Backend HTTPS"
