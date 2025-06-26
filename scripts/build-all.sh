#!/bin/bash

# Script para construir todas as imagens Docker
# Autor: GitHub Copilot
# Data: 26/06/2025

echo "🚀 Construindo imagens Docker para todos os serviços..."

# Definir a tag das imagens
TAG=${1:-latest}
REGISTRY=${2:-"docker.io/fiapx"}
PUSH=${3:-false}

# Verificar se estamos no diretório raiz do projeto
if [ ! -f "go.mod" ]; then
    echo "❌ Este script deve ser executado do diretório raiz do projeto!"
    exit 1
fi

# Função para construir e possivelmente enviar uma imagem
build_and_push() {
    local service=$1
    local dir=$2
    
    if [ -d "$dir" ] && [ -f "$dir/Dockerfile" ]; then
        echo "🔨 Construindo $service..."
        docker build -t $REGISTRY/$service:$TAG $dir
        
        # Verificar se a build foi bem-sucedida
        if [ $? -eq 0 ]; then
            echo "✅ $service construído com sucesso!"
            
            # Enviar imagem para o registry se solicitado
            if [ "$PUSH" = "true" ]; then
                echo "� Enviando $service para o registry..."
                docker push $REGISTRY/$service:$TAG
                
                if [ $? -eq 0 ]; then
                    echo "✅ $service enviado com sucesso!"
                else
                    echo "❌ Falha ao enviar $service para o registry!"
                fi
            fi
        else
            echo "❌ Falha ao construir $service!"
        fi
    else
        echo "⚠️ Diretório ou Dockerfile para $service não encontrado. Pulando..."
    fi
}

# Lista de serviços para construir
echo "🔄 Verificando serviços disponíveis para build..."

# Construir os serviços em ordem hierárquica
build_and_push "auth-service" "./auth-service"
build_and_push "upload-service" "./upload-service"
build_and_push "processing-service" "./processing-service"
build_and_push "storage-service" "./storage-service"
build_and_push "api-gateway" "./api-gateway"

echo ""
echo "✅ Processo de build concluído!"
echo ""

# Listar imagens construídas
echo "Imagens construídas:"
docker images | grep "$REGISTRY" | grep "$TAG"

echo ""
if [ "$PUSH" = "false" ]; then
    echo "Para fazer push para o registry, execute:"
    echo "./scripts/build-all.sh $TAG $REGISTRY true"
    echo ""
    echo "Ou individualmente:"
    echo "docker push $REGISTRY/auth-service:$TAG"
    echo "docker push $REGISTRY/upload-service:$TAG"
    echo "docker push $REGISTRY/processing-service:$TAG"
    echo "docker push $REGISTRY/storage-service:$TAG"
    echo "docker push $REGISTRY/api-gateway:$TAG"
fi

echo ""
echo "Para implantar no Kubernetes:"
echo "./scripts/deploy.sh fiapx"
