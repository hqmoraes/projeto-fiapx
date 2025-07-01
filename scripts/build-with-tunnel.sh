#!/bin/bash

# Script para build com túnel SSH e autenticação Docker Hub
# Autor: GitHub Copilot
# Data: 01/07/2025

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
REMOTE_HOST="worker.wecando.click"
SSH_USER="ubuntu"
SSH_KEY="~/.ssh/keyPrincipal.pem"
DOCKER_USER="hmoraes"
DOCKER_PASS="dckr_pat_8WNLGwKfnO7SDyJWqGVGTM7vV10"
REGISTRY="docker.io/hmoraes"
TAG=${1:-"latest"}
SERVICE=${2:-"frontend"}

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# Função para verificar se o túnel SSH está ativo
check_ssh_tunnel() {
    log "Verificando túnel SSH para $REMOTE_HOST..."
    
    # Testar conexão SSH
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST exit 2>/dev/null; then
        log_success "Túnel SSH está ativo"
        return 0
    else
        log_warning "Túnel SSH não está ativo"
        return 1
    fi
}

# Função para estabelecer túnel SSH
setup_ssh_tunnel() {
    log "Estabelecendo túnel SSH para $REMOTE_HOST..."
    
    # Verificar se a chave SSH existe
    if [ ! -f ~/.ssh/keyPrincipal.pem ]; then
        log_error "Chave SSH não encontrada: ~/.ssh/keyPrincipal.pem"
        exit 1
    fi
    
    # Configurar permissões da chave SSH
    chmod 600 ~/.ssh/keyPrincipal.pem
    
    # Testar conexão e configurar known_hosts se necessário
    ssh-keyscan -H $REMOTE_HOST >> ~/.ssh/known_hosts 2>/dev/null || true
    
    # Testar conexão
    if ssh -o ConnectTimeout=30 -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST "echo 'Conexão SSH estabelecida com sucesso'" 2>/dev/null; then
        log_success "Túnel SSH estabelecido com sucesso"
        return 0
    else
        log_error "Falha ao estabelecer túnel SSH"
        exit 1
    fi
}

# Função para renovar login Docker Hub no servidor remoto
renew_docker_login() {
    log "Renovando login Docker Hub no servidor remoto..."
    
    # Comando para login no Docker Hub no servidor remoto
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST << EOF
        echo "Fazendo login no Docker Hub..."
        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
        if [ \$? -eq 0 ]; then
            echo "Login Docker Hub realizado com sucesso"
        else
            echo "Falha no login Docker Hub"
            exit 1
        fi
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Login Docker Hub renovado com sucesso"
    else
        log_error "Falha ao renovar login Docker Hub"
        exit 1
    fi
}

# Função para verificar se Docker está rodando no servidor remoto
check_remote_docker() {
    log "Verificando Docker no servidor remoto..."
    
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST "docker --version && docker info > /dev/null 2>&1"
    
    if [ $? -eq 0 ]; then
        log_success "Docker está funcionando no servidor remoto"
    else
        log_error "Docker não está funcionando no servidor remoto"
        exit 1
    fi
}

# Função para sincronizar código para o servidor remoto
sync_code_to_remote() {
    log "Sincronizando código para o servidor remoto..."
    
    # Criar diretório no servidor remoto se não existir
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST "mkdir -p ~/projeto-fiapx"
    
    # Sincronizar apenas arquivos necessários para o frontend
    rsync -avz --delete \
        -e "ssh -i ~/.ssh/keyPrincipal.pem" \
        ./frontend/ \
        ubuntu@$REMOTE_HOST:~/projeto-fiapx/frontend/
    
    if [ $? -eq 0 ]; then
        log_success "Código sincronizado com sucesso"
    else
        log_error "Falha ao sincronizar código"
        exit 1
    fi
}

# Função para fazer build no servidor remoto
build_on_remote() {
    log "Executando build no servidor remoto..."
    
    # Script para executar no servidor remoto
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST << EOF
        cd ~/projeto-fiapx/frontend
        
        echo "Construindo imagem Docker para $SERVICE..."
        
        # Build da imagem
        docker build -t $REGISTRY/$SERVICE:$TAG .
        
        if [ \$? -eq 0 ]; then
            echo "Build concluído com sucesso"
            
            # Push da imagem
            echo "Enviando imagem para o registry..."
            docker push $REGISTRY/$SERVICE:$TAG
            
            if [ \$? -eq 0 ]; then
                echo "Imagem enviada com sucesso para $REGISTRY/$SERVICE:$TAG"
            else
                echo "Falha ao enviar imagem"
                exit 1
            fi
        else
            echo "Falha no build"
            exit 1
        fi
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Build e push concluídos com sucesso"
    else
        log_error "Falha no build remoto"
        exit 1
    fi
}

# Função para atualizar deployment no Kubernetes
update_k8s_deployment() {
    log "Atualizando deployment no Kubernetes..."
    
    ssh -i ~/.ssh/keyPrincipal.pem ubuntu@$REMOTE_HOST << EOF
        # Reiniciar deployment para puxar nova imagem
        kubectl rollout restart deployment/$SERVICE-deployment -n fiapx
        
        # Aguardar rollout completar
        kubectl rollout status deployment/$SERVICE-deployment -n fiapx --timeout=300s
        
        if [ \$? -eq 0 ]; then
            echo "Deployment atualizado com sucesso"
            
            # Mostrar status dos pods
            kubectl get pods -n fiapx -l app=$SERVICE
        else
            echo "Falha ao atualizar deployment"
            exit 1
        fi
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Deployment Kubernetes atualizado com sucesso"
    else
        log_error "Falha ao atualizar deployment Kubernetes"
        exit 1
    fi
}

# Função principal
main() {
    log "🚀 Iniciando build com túnel SSH para $SERVICE:$TAG"
    
    # Verificar se estamos no diretório correto
    if [ ! -d "frontend" ]; then
        log_error "Diretório frontend não encontrado. Execute este script do diretório raiz do projeto."
        exit 1
    fi
    
    # 1. Verificar e estabelecer túnel SSH
    if ! check_ssh_tunnel; then
        setup_ssh_tunnel
    fi
    
    # 2. Verificar Docker no servidor remoto
    check_remote_docker
    
    # 3. Renovar login Docker Hub
    renew_docker_login
    
    # 4. Sincronizar código
    sync_code_to_remote
    
    # 5. Fazer build no servidor remoto
    build_on_remote
    
    # 6. Atualizar deployment Kubernetes
    update_k8s_deployment
    
    log_success "🎉 Build e deploy concluídos com sucesso!"
    log "📱 Acesse: https://api.wecando.click"
    log "🔍 Verifique os pods: kubectl get pods -n fiapx"
}

# Função de ajuda
show_help() {
    echo "Uso: $0 [TAG] [SERVICE]"
    echo ""
    echo "Parâmetros:"
    echo "  TAG      - Tag da imagem Docker (padrão: latest)"
    echo "  SERVICE  - Nome do serviço (padrão: frontend)"
    echo ""
    echo "Exemplos:"
    echo "  $0                      # Build frontend:latest"
    echo "  $0 v2.5.0               # Build frontend:v2.5.0"
    echo "  $0 latest frontend      # Build frontend:latest"
    echo ""
    echo "O script irá:"
    echo "  1. Verificar/estabelecer túnel SSH"
    echo "  2. Renovar login Docker Hub no servidor"
    echo "  3. Sincronizar código para o servidor"
    echo "  4. Fazer build e push da imagem"
    echo "  5. Atualizar deployment Kubernetes"
}

# Verificar argumentos
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac
