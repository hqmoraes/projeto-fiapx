#!/bin/bash

# Build das imagens Docker diretamente no servidor ARM64
# Autor: GitHub Copilot

set -e

echo "🚀 Construindo imagens Docker no servidor ARM64..."

# Configurações
REMOTE_HOST="worker.wecando.click"
REMOTE_USER="ubuntu"
SSH_KEY="~/.ssh/keyPrincipal.pem"
DOCKER_USERNAME="hmoraes"

# Serviços para build
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Função para executar comando no servidor remoto
remote_exec() {
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "$@"
}

# Verificar se o Docker está instalado no servidor remoto
echo "📋 Verificando Docker no servidor remoto..."
if ! remote_exec "docker version" >/dev/null 2>&1; then
    echo "❌ Docker não está instalado ou acessível no servidor remoto"
    exit 1
fi

# Copiar código fonte para o servidor remoto
echo "📋 Copiando código fonte para o servidor remoto..."
rsync -avz -e "ssh -i ~/.ssh/keyPrincipal.pem" \
    --exclude='*.tar' \
    --exclude='temp/' \
    --exclude='uploads/' \
    --exclude='outputs/' \
    --exclude='.git/' \
    /home/hqmoraes/Documents/fiap/projeto-fiapx/ \
    ubuntu@worker.wecando.click:~/projeto-fiapx/

# Login no Docker Hub no servidor remoto
echo "🔐 Fazendo login no Docker Hub no servidor remoto..."
echo "Você precisará inserir suas credenciais do Docker Hub:"
remote_exec "docker login"

# Build e push para cada serviço
for service in "${SERVICES[@]}"; do
    echo "🔨 Construindo $service no servidor ARM64..."
    
    # Build da imagem no servidor remoto
    remote_exec "cd ~/projeto-fiapx/$service && docker build -t $DOCKER_USERNAME/$service:latest ."
    
    if [ $? -eq 0 ]; then
        echo "✅ $service construído com sucesso!"
        
        # Push da imagem
        echo "📤 Enviando $service para Docker Hub..."
        remote_exec "docker push $DOCKER_USERNAME/$service:latest"
        
        if [ $? -eq 0 ]; then
            echo "✅ $service enviado com sucesso!"
        else
            echo "❌ Falha ao enviar $service"
        fi
    else
        echo "❌ Falha ao construir $service"
    fi
done

echo "🎉 Build e push concluídos!"
echo "📋 Imagens disponíveis para linux/arm64:"
for service in "${SERVICES[@]}"; do
    echo "  - $DOCKER_USERNAME/$service:latest"
done

# Limpar imagens locais do servidor para economizar espaço
echo "🧹 Limpando imagens locais do servidor..."
remote_exec "docker system prune -f"

echo "✅ Processo concluído! As imagens agora são compatíveis com ARM64."
