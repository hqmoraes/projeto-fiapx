#!/bin/bash

# Script de configuração inicial do projeto
# Autor: GitHub Copilot
# Data: 26/06/2025

echo "🚀 Iniciando setup do projeto FiapX..."

# Verificar dependências
echo "🔍 Verificando dependências..."

# Verificar Go
if ! command -v go &> /dev/null; then
    echo "❌ Go não encontrado. Por favor, instale Go 1.21 ou superior."
    exit 1
fi
go_version=$(go version | awk '{print $3}')
echo "✅ Go instalado: $go_version"

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não encontrado. Por favor, instale Docker."
    exit 1
fi
docker_version=$(docker --version | awk '{print $3}')
echo "✅ Docker instalado: $docker_version"

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose não encontrado. Por favor, instale Docker Compose."
    exit 1
fi
docker_compose_version=$(docker-compose --version | awk '{print $3}')
echo "✅ Docker Compose instalado: $docker_compose_version"

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Obrigatório para implantar no cluster Kubernetes."
    echo "   Instale com: curl -LO 'https://dl.k8s.io/release/stable.txt' && curl -LO \"https://dl.k8s.io/release/$(cat stable.txt)/bin/linux/amd64/kubectl\" && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
    exit 1
else
    kubectl_version=$(kubectl version --client --short | awk '{print $3}')
    echo "✅ kubectl instalado: $kubectl_version"
fi

# Verificar SSH
if ! command -v ssh &> /dev/null; then
    echo "❌ SSH não encontrado. Obrigatório para acessar o cluster Kubernetes remoto."
    exit 1
fi

# Verificar existência da chave SSH
SSH_KEY="$HOME/.ssh/keyPrincipal.pem"
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Chave SSH não encontrada em $SSH_KEY. Obrigatória para acessar o cluster Kubernetes remoto."
    exit 1
else
    echo "✅ Chave SSH encontrada em $SSH_KEY"
fi

# Verificar permissões da chave SSH
chmod 600 $SSH_KEY
echo "✅ Permissões da chave SSH ajustadas"

# Verificar FFmpeg (necessário para o serviço de processamento)
if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️ FFmpeg não encontrado. O serviço de processamento pode não funcionar corretamente."
    echo "   Instale com: sudo apt-get install ffmpeg"
else
    ffmpeg_version=$(ffmpeg -version | head -n1 | awk '{print $3}')
    echo "✅ FFmpeg instalado: $ffmpeg_version"
fi

echo ""
echo "📁 Configurando diretórios do projeto..."

# Tornar os scripts executáveis
chmod +x scripts/*.sh
chmod +x *.sh

# Verificar e criar diretórios necessários
mkdir -p infrastructure/kubernetes/auth-service
mkdir -p infrastructure/kubernetes/upload-service
mkdir -p infrastructure/kubernetes/processing-service
mkdir -p infrastructure/kubernetes/storage-service
mkdir -p infrastructure/kubernetes/api-gateway
mkdir -p infrastructure/kubernetes/monitoring

echo ""
echo "🗄️ Configurando ambiente de desenvolvimento local..."

# Tornar scripts de inicialização PostgreSQL executáveis
if [ -d "infrastructure/postgres-init" ]; then
    chmod +x infrastructure/postgres-init/*.sh
fi

echo ""
echo "🔄 Verificando ambiente Kubernetes..."
./scripts/check-k8s.sh

echo ""
echo "🛠️ Verificando imagens Docker para microsserviços..."
# Verificar se as imagens Docker existem localmente
echo "Verifique se os Dockerfiles estão presentes para todos os serviços:"
ls -la */Dockerfile || echo "Nem todos os serviços têm Dockerfile ainda"

echo ""
echo "🌟 Setup concluído com sucesso!"
echo ""
echo "IMPORTANTE: Todas as ferramentas e recursos serão implantados no cluster Kubernetes."
echo "O ambiente Docker Compose local é apenas para desenvolvimento e testes."
echo ""
echo "Para implantar no cluster Kubernetes:"
echo "1. Certifique-se de que o túnel SSH está ativo:"
echo "   ./setup-k8s-tunnel.sh"
echo ""
echo "2. Construa as imagens Docker:"
echo "   ./scripts/build-all.sh"
echo ""
echo "3. Implante a aplicação:"
echo "   ./scripts/deploy.sh"
echo ""
echo "Para desenvolvimento local (opcional):"
echo "cd infrastructure && docker-compose up -d"
echo ""
