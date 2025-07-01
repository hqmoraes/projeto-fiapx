#!/bin/bash

# Script para deploy completo do frontend HTTPS - fiapx.wecando.click
# Uso: ./deploy-frontend-https-complete.sh [--build-only] [--deploy-only]

set -e

# Configurações
DOCKER_REGISTRY="hmoraes"
IMAGE_NAME="fiapx-frontend"
IMAGE_TAG="v2.4-https"
NAMESPACE="fiapx"
K8S_NODE_IP="18.118.109.214"  # IP do seu worker node
SSH_USER="ubuntu"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_step() {
    echo ""
    print_color $BLUE "🔄 $1"
    echo "=================================================="
}

# Processamento de argumentos
BUILD_ONLY=false
DEPLOY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [--build-only] [--deploy-only]"
            echo ""
            echo "Opções:"
            echo "  --build-only   Apenas faz build da imagem Docker"
            echo "  --deploy-only  Apenas faz deploy (sem build)"
            echo "  -h, --help     Mostra esta ajuda"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            exit 1
            ;;
    esac
done

# Verificar se estamos no diretório correto
if [ ! -d "frontend" ]; then
    print_color $RED "❌ Diretório frontend não encontrado!"
    print_color $YELLOW "💡 Execute este script a partir da raiz do projeto"
    exit 1
fi

print_color $GREEN "🚀 Deploy do Frontend HTTPS para fiapx.wecando.click"
echo ""

# Build da imagem Docker
if [ "$DEPLOY_ONLY" != true ]; then
    print_step "Step 1: Build da Imagem Docker"
    
    # Verificar se Docker está disponível
    if ! command -v docker >/dev/null 2>&1; then
        print_color $RED "❌ Docker não encontrado. Instale o Docker primeiro."
        exit 1
    fi
    
    cd frontend
    
    print_color $YELLOW "📋 Verificando arquivos de configuração..."
    
    # Verificar se config-https.js existe
    if [ ! -f "config-https.js" ]; then
        print_color $RED "❌ Arquivo config-https.js não encontrado!"
        exit 1
    fi
    
    print_color $GREEN "✅ Arquivo config-https.js encontrado"
    
    # Mostrar configurações que serão usadas
    print_color $YELLOW "📋 Configurações HTTPS que serão incluídas:"
    grep -E "(AUTH_SERVICE_URL|UPLOAD_SERVICE_URL|PROCESSING_SERVICE_URL|STORAGE_SERVICE_URL)" config-https.js || true
    
    print_color $YELLOW "🐳 Fazendo build da imagem Docker..."
    docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG .
    
    print_color $GREEN "✅ Build da imagem concluído: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    
    # Push para Docker Hub
    print_color $YELLOW "📤 Fazendo push para Docker Hub..."
    docker push $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
    
    print_color $GREEN "✅ Push para Docker Hub concluído"
    
    cd ..
fi

# Deploy no Kubernetes
if [ "$BUILD_ONLY" != true ]; then
    print_step "Step 2: Deploy no Kubernetes"
    
    # Atualizar deployment para usar nova imagem
    print_color $YELLOW "📝 Atualizando deployment..."
    
    # Fazer backup do deployment atual
    cp infrastructure/kubernetes/frontend/frontend.yaml infrastructure/kubernetes/frontend/frontend.yaml.backup
    
    # Atualizar imagem no deployment
    sed -i "s|image: hmoraes/fiapx-frontend:.*|image: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG|g" infrastructure/kubernetes/frontend/frontend.yaml
    
    print_color $GREEN "✅ Deployment atualizado para usar imagem: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    
    # Deploy via SSH
    print_color $YELLOW "🚀 Fazendo deploy no cluster Kubernetes..."
    
    # Verificar conectividade SSH
    if ! ssh -o ConnectTimeout=5 $SSH_USER@$K8S_NODE_IP "echo 'SSH conectado com sucesso'" 2>/dev/null; then
        print_color $RED "❌ Não foi possível conectar via SSH ao node $K8S_NODE_IP"
        print_color $YELLOW "💡 Verifique se a chave SSH está configurada corretamente"
        exit 1
    fi
    
    print_color $GREEN "✅ Conectado via SSH ao cluster"
    
    # Enviar arquivos para o cluster
    scp infrastructure/kubernetes/frontend/frontend.yaml $SSH_USER@$K8S_NODE_IP:/tmp/
    scp infrastructure/kubernetes/ingress/fiapx-ingress.yaml $SSH_USER@$K8S_NODE_IP:/tmp/
    
    # Aplicar configurações
    ssh $SSH_USER@$K8S_NODE_IP "
        echo '🔄 Aplicando configurações do frontend...'
        kubectl apply -f /tmp/frontend.yaml
        
        echo '🔄 Aplicando configurações do Ingress...'
        kubectl apply -f /tmp/fiapx-ingress.yaml
        
        echo '🔄 Forçando atualização do deployment...'
        kubectl rollout restart deployment/frontend-deployment -n $NAMESPACE
        
        echo '⏳ Aguardando rollout do frontend...'
        kubectl rollout status deployment/frontend-deployment -n $NAMESPACE --timeout=300s
        
        echo '📋 Status dos pods:'
        kubectl get pods -n $NAMESPACE -l app=frontend
        
        echo '📋 Status do ingress:'
        kubectl get ingress fiapx-ingress -n $NAMESPACE
        
        echo '🧹 Limpando arquivos temporários...'
        rm -f /tmp/frontend.yaml /tmp/fiapx-ingress.yaml
    "
    
    print_color $GREEN "✅ Deploy concluído com sucesso!"
fi

print_step "Step 3: Verificação e Testes"

# Aguardar um pouco para estabilizar
sleep 10

# Testar conectividade
print_color $YELLOW "🔍 Testando conectividade com fiapx.wecando.click..."

# Testar HTTPS
if curl -s -k --connect-timeout 10 https://fiapx.wecando.click >/dev/null; then
    print_color $GREEN "✅ HTTPS conectando com sucesso"
else
    print_color $YELLOW "⚠️  HTTPS ainda não respondendo (pode levar alguns minutos para propagar)"
fi

# Verificar certificado SSL
print_color $YELLOW "🔐 Verificando certificado SSL..."
if echo | openssl s_client -servername fiapx.wecando.click -connect fiapx.wecando.click:443 2>/dev/null | grep -q "Verify return code: 0"; then
    print_color $GREEN "✅ Certificado SSL válido"
else
    print_color $YELLOW "⚠️  Certificado SSL ainda sendo emitido (normal para primeira execução)"
fi

print_step "🎉 Deploy Concluído!"

echo ""
print_color $BLUE "📊 Resumo do Deploy:"
echo "- ✅ Imagem Docker: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
echo "- ✅ Namespace: $NAMESPACE"
echo "- ✅ Ingress: fiapx-ingress"
echo "- ✅ Domínio: https://fiapx.wecando.click"
echo ""
print_color $BLUE "🌐 URLs de Acesso:"
echo "- Frontend: https://fiapx.wecando.click"
echo "- API Auth: https://fiapx.wecando.click/api/auth"
echo "- API Upload: https://fiapx.wecando.click/api/upload"
echo "- API Processing: https://fiapx.wecando.click/api/processing"
echo "- API Storage: https://fiapx.wecando.click/api/storage"
echo ""
print_color $BLUE "📋 Comandos úteis:"
echo "- Ver pods: kubectl get pods -n $NAMESPACE -l app=frontend"
echo "- Ver logs: kubectl logs -n $NAMESPACE -l app=frontend -f"
echo "- Ver ingress: kubectl get ingress fiapx-ingress -n $NAMESPACE"
echo "- Rollback: kubectl rollout undo deployment/frontend-deployment -n $NAMESPACE"
echo ""
print_color $YELLOW "💡 Aguarde alguns minutos para o DNS propagar completamente"
print_color $YELLOW "💡 Teste o site em: https://fiapx.wecando.click"
