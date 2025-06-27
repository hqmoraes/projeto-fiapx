#!/bin/bash

# Script para expor os microsserviços via NodePort para acesso externo
# Autor: GitHub Copilot

set -e

echo "🌐 Configurando acesso externo aos microsserviços via NodePort..."

# Expor auth-service na porta 30081
echo "🔧 Expondo auth-service via NodePort..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl expose deployment auth-service --type=NodePort --port=8081 --target-port=8081 --name=auth-service-external -n fiapx" || echo "Serviço já existe"

# Expor upload-service na porta 30080
echo "🔧 Expondo upload-service via NodePort..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl expose deployment upload-service --type=NodePort --port=8080 --target-port=8080 --name=upload-service-external -n fiapx" || echo "Serviço já existe"

# Expor processing-service na porta 30082
echo "🔧 Expondo processing-service via NodePort..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl expose deployment processing-service --type=NodePort --port=8080 --target-port=8080 --name=processing-service-external -n fiapx" || echo "Serviço já existe"

# Expor storage-service na porta 30083
echo "🔧 Expondo storage-service via NodePort..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl expose deployment storage-service --type=NodePort --port=8080 --target-port=8080 --name=storage-service-external -n fiapx" || echo "Serviço já existe"

echo "📋 Verificando serviços expostos..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl get svc -n fiapx | grep external"

echo "🌐 Obtendo IP externo dos nodes..."
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl get nodes -o wide | grep -E 'EXTERNAL-IP|ip-'"

echo ""
echo "✅ Configuração concluída!"
echo ""
echo "📋 Para acessar os serviços externamente, use:"
echo "   - Auth Service: http://<NODE_EXTERNAL_IP>:<NodePort>"
echo "   - Upload Service: http://<NODE_EXTERNAL_IP>:<NodePort>" 
echo "   - Processing Service: http://<NODE_EXTERNAL_IP>:<NodePort>"
echo "   - Storage Service: http://<NODE_EXTERNAL_IP>:<NodePort>"
echo ""
echo "🔍 Para obter o IP externo e portas específicas, execute:"
echo "   kubectl get svc -n fiapx | grep external"
