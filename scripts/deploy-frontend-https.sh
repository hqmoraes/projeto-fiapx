#!/bin/bash

# Script para deploy do frontend com configuração HTTPS
# Atualiza configuração e faz deploy no cluster

set -e

echo "🚀 Deploy do Frontend com HTTPS"
echo "=================================="

# IPs dos nós do cluster
WORKER_IP="54.210.189.246"  # worker.wecando.click
MASTER_IP="44.210.118.109"  # master.wecando.click

echo "📍 Usando Worker IP: $WORKER_IP para deploy"

# Verificar se o túnel SSH está ativo
echo "🔍 Verificando conectividade com o cluster..."

# Testar conectividade via SSH
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes root@$WORKER_IP "echo 'SSH OK'" &> /dev/null; then
    echo "❌ Não foi possível conectar via SSH ao worker ($WORKER_IP)"
    echo "💡 Certifique-se de que:"
    echo "   - A chave SSH está configurada"
    echo "   - O túnel K8s está ativo: ./k8s-tunnel.sh"
    exit 1
fi

echo "✅ Conectividade SSH OK"

# Verificar se o kubectl está funcionando
if ! kubectl get nodes &> /dev/null; then
    echo "❌ kubectl não está funcionando"
    echo "💡 Execute primeiro: ./k8s-tunnel.sh"
    exit 1
fi

echo "✅ kubectl funcionando"

# Build da nova imagem do frontend com configuração HTTPS
echo "🔨 Fazendo build da nova imagem do frontend..."

cd frontend

# Verificar se o Dockerfile existe
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile não encontrado em frontend/"
    exit 1
fi

# Build da imagem
echo "🐳 Fazendo build da imagem Docker..."
docker build -t hmoraes/fiapx-frontend:https .

# Push da imagem
echo "📤 Fazendo push da imagem..."
docker push hmoraes/fiapx-frontend:https

cd ..

# Atualizar deployment do frontend
echo "🔧 Atualizando deployment do frontend..."

# Criar um patch para o deployment
kubectl patch deployment frontend-deployment -n fiapx -p '{
    "spec": {
        "template": {
            "spec": {
                "containers": [{
                    "name": "frontend",
                    "image": "hmoraes/fiapx-frontend:https"
                }]
            }
        }
    }
}'

# Aguardar rollout
echo "⏳ Aguardando rollout do deployment..."
kubectl rollout status deployment/frontend-deployment -n fiapx --timeout=300s

# Verificar pods
echo "📋 Status dos pods:"
kubectl get pods -l app=frontend -n fiapx

# Verificar serviços
echo "📋 Status dos serviços:"
kubectl get services -n fiapx | grep frontend

# Verificar ingress
echo "📋 Status do Ingress:"
kubectl get ingress -n fiapx

echo "🎉 Deploy concluído!"
echo ""
echo "🌐 Frontend disponível em:"
echo "   - https://fiapx.wecando.click (novo domínio HTTPS)"
echo "   - http://$WORKER_IP:30080 (NodePort direto)"
echo ""
echo "🔍 Para verificar logs: kubectl logs -f deployment/frontend-deployment -n fiapx"
