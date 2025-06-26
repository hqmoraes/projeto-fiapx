#!/bin/bash

# Build e push das imagens Docker para múltiplas arquiteturas (amd64 e arm64)
# Autor: GitHub Copilot

set -e

echo "🚀 Construindo e fazendo push das imagens Docker para múltiplas arquiteturas..."

# Verificar se docker buildx está disponível
if ! docker buildx version >/dev/null 2>&1; then
    echo "❌ Docker buildx não está disponível. Instalando..."
    docker buildx install
fi

# Criar builder para multi-arquitetura se não existir
if ! docker buildx ls | grep -q "multiarch"; then
    echo "🔧 Criando builder multi-arquitetura..."
    docker buildx create --name multiarch --driver docker-container --bootstrap
fi

# Usar o builder multi-arquitetura
echo "🔧 Configurando builder multi-arquitetura..."
docker buildx use multiarch

# Configurações
DOCKER_USERNAME="hmoraes"
PLATFORMS="linux/amd64,linux/arm64"

# Serviços para build
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Login no Docker Hub
echo "🔐 Fazendo login no Docker Hub..."
if ! docker login; then
    echo "❌ Falha no login do Docker Hub"
    exit 1
fi

# Build e push para cada serviço
for service in "${SERVICES[@]}"; do
    echo "🔨 Construindo $service para múltiplas arquiteturas..."
    
    # Navegar para o diretório do serviço
    cd "/home/hqmoraes/Documents/fiap/projeto-fiapx/$service"
    
    # Verificar se o Dockerfile existe
    if [ ! -f "Dockerfile" ]; then
        echo "❌ Dockerfile não encontrado em $service"
        continue
    fi
    
    # Build e push multi-arquitetura
    docker buildx build \
        --platform $PLATFORMS \
        --tag $DOCKER_USERNAME/$service:latest \
        --tag $DOCKER_USERNAME/$service:v1.0 \
        --push \
        .
    
    if [ $? -eq 0 ]; then
        echo "✅ $service construído e enviado com sucesso!"
    else
        echo "❌ Falha ao construir $service"
    fi
    
    # Voltar ao diretório root
    cd "/home/hqmoraes/Documents/fiap/projeto-fiapx"
done

echo "🎉 Build e push concluídos!"
echo "📋 Imagens disponíveis para linux/amd64 e linux/arm64:"
for service in "${SERVICES[@]}"; do
    echo "  - $DOCKER_USERNAME/$service:latest"
    echo "  - $DOCKER_USERNAME/$service:v1.0"
done

echo ""
echo "🔍 Verificando imagens no Docker Hub..."
for service in "${SERVICES[@]}"; do
    echo "📦 Verificando manifesto de $service..."
    docker buildx imagetools inspect $DOCKER_USERNAME/$service:latest
    echo "---"
done
