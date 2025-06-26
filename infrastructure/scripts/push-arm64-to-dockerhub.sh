#!/bin/bash

# Push das imagens ARM64 para Docker Hub
# Executar no servidor remoto

set -e

echo "🚀 Fazendo push das imagens ARM64 para Docker Hub..."

# Configurações
DOCKER_USERNAME="hmoraes"
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Fazer push de cada serviço
for service in "${SERVICES[@]}"; do
    echo "📤 Fazendo push de $service..."
    
    # Fazer push da versão ARM64
    docker push $DOCKER_USERNAME/$service:arm64-latest
    
    # Também fazer push como 'latest' para substituir a versão amd64
    docker tag $DOCKER_USERNAME/$service:arm64-latest $DOCKER_USERNAME/$service:latest
    docker push $DOCKER_USERNAME/$service:latest
    
    if [ $? -eq 0 ]; then
        echo "✅ $service enviado com sucesso!"
    else
        echo "❌ Falha ao enviar $service"
    fi
done

echo "🎉 Push concluído! Imagens ARM64 disponíveis no Docker Hub."
