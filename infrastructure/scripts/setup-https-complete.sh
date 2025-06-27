#!/bin/bash

# Script principal para configurar HTTPS nos microsserviços FIAP X
# Solução: nginx-ingress + cert-manager + Route53 + Let's Encrypt

set -e

echo "🚀 FIAP X - Configuração HTTPS Completa"
echo "======================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verificar pré-requisitos
log "🔍 Verificando pré-requisitos..."

if ! command -v kubectl &> /dev/null; then
    error "kubectl não encontrado!"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    error "AWS CLI não encontrada!"
    exit 1
fi

# Verificar conexão com o cluster
log "📡 Verificando conexão com o cluster Kubernetes..."
if ! kubectl get nodes &> /dev/null; then
    error "Não foi possível conectar ao cluster Kubernetes!"
    echo "Certifique-se de que o KUBECONFIG está configurado corretamente."
    exit 1
fi

NODES=$(kubectl get nodes --no-headers | wc -l)
log "✅ Cluster conectado! Nodes: $NODES"

# 1. Configurar DNS no Route53
log "🌐 Configurando DNS no Route53..."
./setup-route53-dns.sh

# 2. Instalar nginx-ingress
log "📦 Instalando nginx-ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

log "⏳ Aguardando nginx-ingress ficar pronto..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# 3. Instalar cert-manager
log "🔐 Instalando cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

log "⏳ Aguardando cert-manager ficar pronto..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=cert-manager \
  --timeout=300s

# 4. Configurar IAM Role para cert-manager (Route53)
log "🔑 Configurando permissões IAM para Route53..."

# Criar policy para Route53
cat > /tmp/route53-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:GetChange",
                "route53:ChangeResourceRecordSets",
                "route53:ListHostedZonesByName"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/*",
                "arn:aws:route53:::change/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Criar policy
POLICY_ARN=$(aws iam create-policy \
    --policy-name FiapXCertManagerRoute53Policy \
    --policy-document file:///tmp/route53-policy.json \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || echo "Policy já existe")

if [[ $POLICY_ARN == *"arn:aws"* ]]; then
    log "✅ Policy IAM criada: $POLICY_ARN"
else
    POLICY_ARN=$(aws iam list-policies \
        --query "Policies[?PolicyName=='FiapXCertManagerRoute53Policy'].Arn" \
        --output text)
    log "✅ Policy IAM existente: $POLICY_ARN"
fi

# 5. Aplicar ClusterIssuer
log "📜 Aplicando ClusterIssuer do Let's Encrypt..."
kubectl apply -f ../kubernetes/cert-manager/cluster-issuer.yaml

# 6. Aguardar ClusterIssuer ficar pronto
log "⏳ Aguardando ClusterIssuer ficar pronto..."
sleep 30

# 7. Aplicar Ingress
log "🌍 Aplicando configuração do Ingress..."
kubectl apply -f ../kubernetes/ingress/fiapx-ingress.yaml

# 8. Aguardar certificado
log "📋 Verificando status do certificado..."
echo "Execute o comando abaixo para monitorar:"
echo "kubectl get certificate fiapx-tls-secret -w"
echo ""

# 9. Verificar se tudo está funcionando
log "🔍 Verificando status dos recursos..."

echo ""
echo "📊 Status dos Pods:"
kubectl get pods -A | grep -E "(ingress|cert-manager)"

echo ""
echo "📋 Status do Ingress:"
kubectl get ingress fiapx-ingress

echo ""
echo "🔐 Status do Certificado:"
kubectl get certificate fiapx-tls-secret

echo ""
echo "🌐 Endpoints HTTPS configurados:"
echo "   https://api.wecando.click/auth/health"
echo "   https://api.wecando.click/upload/health"
echo "   https://api.wecando.click/processing/health"
echo "   https://api.wecando.click/storage/health"

echo ""
log "🎉 Configuração HTTPS concluída!"
echo ""
echo "🧪 Para testar:"
echo "curl -k https://api.wecando.click/auth/health"
echo ""
echo "📝 Para atualizar o frontend, modifique config.js com:"
echo "AUTH_SERVICE_URL: 'https://api.wecando.click/auth'"
echo "UPLOAD_SERVICE_URL: 'https://api.wecando.click/upload'"
echo "PROCESSING_SERVICE_URL: 'https://api.wecando.click/processing'"
echo "STORAGE_SERVICE_URL: 'https://api.wecando.click/storage'"

# Cleanup
rm -f /tmp/route53-policy.json
