#!/bin/bash

# Script para fazer push das imagens para o Docker Hub
set -e

echo "🚀 Fazendo push das imagens para o Docker Hub..."

# Lista de serviços
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Seu username do Docker Hub (ajuste se necessário)
DOCKER_USERNAME="hmoraes"

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "📦 Processando $SERVICE..."
    
    # Tag original local
    LOCAL_TAG="fiapx/$SERVICE:latest"
    
    # Nova tag para Docker Hub
    DOCKERHUB_TAG="$DOCKER_USERNAME/$SERVICE:latest"
    
    # Verificar se a imagem local existe
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$LOCAL_TAG"; then
        echo "  ✅ Imagem local encontrada: $LOCAL_TAG"
        
        # Re-tag para Docker Hub
        echo "  🏷️  Criando tag: $DOCKERHUB_TAG"
        docker tag "$LOCAL_TAG" "$DOCKERHUB_TAG"
        
        # Push para Docker Hub
        echo "  📤 Fazendo push para Docker Hub..."
        docker push "$DOCKERHUB_TAG"
        
        echo "  ✅ $SERVICE enviado com sucesso!"
    else
        echo "  ❌ Imagem local não encontrada: $LOCAL_TAG"
        echo "  🔧 Execute o build primeiro: docker build -t $LOCAL_TAG ./$SERVICE"
    fi
done

echo ""
echo "🎉 Push para Docker Hub concluído!"
echo ""
echo "📋 Para usar as imagens do Docker Hub, atualize os manifests Kubernetes com:"
for SERVICE in "${SERVICES[@]}"; do
    echo "  - image: $DOCKER_USERNAME/$SERVICE:latest"
done
