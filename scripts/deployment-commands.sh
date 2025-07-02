#!/bin/bash

# FIAP-X - Comandos para Deploy Completo
# Execute estes comandos quando o kubectl estiver disponível

set -e

echo "🚀 FIAP-X - Deploy Completo Iniciando..."

# 1. Setup do Amazon SES
echo "📧 1. Configurando Amazon SES..."
./scripts/auto-setup-ses.sh

# 2. Aplicar todos os manifests atualizados
echo "⚙️ 2. Aplicando manifests do Kubernetes..."
kubectl apply -f infrastructure/kubernetes/

# 3. Verificar status de todos os deployments
echo "📊 3. Verificando status dos deployments..."
kubectl get deployments -n fiapx

# 4. Verificar pods
echo "🔍 4. Verificando pods..."
kubectl get pods -n fiapx

# 5. Verificar services
echo "🌐 5. Verificando services..."
kubectl get services -n fiapx

# 6. Testar endpoints
echo "🧪 6. Testando endpoints..."
echo "Aguarde os pods ficarem prontos e teste:"
echo "curl -k https://fiapx.wecando.click/auth/health"
echo "curl -k https://fiapx.wecando.click/upload/health"
echo "curl -k https://fiapx.wecando.click/processing/health"
echo "curl -k https://fiapx.wecando.click/storage/health"

echo "✅ Deploy completo finalizado!"
