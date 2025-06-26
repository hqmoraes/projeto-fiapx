#!/bin/bash

# Script completo para resolver o problema de arquitetura
# Compila todos os serviços no servidor ARM64 e faz deploy

set -e

echo "🚀 Resolvendo problema de arquitetura - Build ARM64 completo"

REMOTE_HOST="worker.wecando.click"
REMOTE_USER="ubuntu"
SSH_KEY="~/.ssh/keyPrincipal.pem"
DOCKER_USERNAME="hmoraes"

# Serviços para processar
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

echo "📋 Copiando código fonte completo para o servidor..."
rsync -avz -e "ssh -i ~/.ssh/keyPrincipal.pem" \
    --exclude='*.tar' \
    --exclude='temp/' \
    --exclude='uploads/' \
    --exclude='outputs/' \
    --exclude='.git/' \
    /home/hqmoraes/Documents/fiap/projeto-fiapx/ \
    ubuntu@worker.wecando.click:~/projeto-fiapx-arm64/

echo "🔨 Fazendo build de todos os serviços no servidor ARM64..."
for service in "${SERVICES[@]}"; do
    echo "📦 Processando $service..."
    
    # Build da imagem
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click \
        "cd ~/projeto-fiapx-arm64/$service && docker build -t $DOCKER_USERNAME/$service:arm64-latest ."
    
    if [ $? -eq 0 ]; then
        echo "✅ $service compilado com sucesso para ARM64"
    else
        echo "❌ Falha ao compilar $service"
        continue
    fi
done

echo "🔄 Atualizando deployments para usar imagens ARM64 locais..."
for service in "${SERVICES[@]}"; do
    echo "🔄 Atualizando $service..."
    
    # Atualizar deployment para usar imagePullPolicy: Never e a imagem local
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click \
        "kubectl patch deployment $service -n fiapx -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$service\",\"image\":\"$DOCKER_USERNAME/$service:arm64-latest\",\"imagePullPolicy\":\"Never\"}]}}}}'"
    
    # Forçar rollout restart
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click \
        "kubectl rollout restart deployment $service -n fiapx"
done

echo "⏳ Aguardando deployments..."
sleep 30

echo "📊 Verificando status final..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl get pods -n fiapx"

echo "🔍 Verificando logs de cada serviço..."
for service in "${SERVICES[@]}"; do
    echo "📋 Logs do $service:"
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click \
        "kubectl logs -l app=$service -n fiapx --tail=3 2>/dev/null || echo 'Sem logs disponíveis'"
    echo "---"
done

echo "✅ Processo concluído! Todos os serviços agora usam imagens ARM64."
