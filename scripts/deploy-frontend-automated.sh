#!/bin/bash

# Script automatizado para build e deploy do frontend
# Inclui verificação de túnel SSH, login Docker Hub e deploy Kubernetes

set -e  # Parar em caso de erro

# Configurações
WORKER_HOST="ubuntu@worker.wecando.click"
SSH_KEY="~/.ssh/keyPrincipal.pem"
DOCKER_USER="hmoraes"
DOCKER_PASS="Ch@plinh45"
IMAGE_NAME="hmoraes/fiapx-frontend"
IMAGE_TAG="latest"
KUBE_CONFIG="kubeconfig.yaml"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se o túnel SSH está ativo
check_ssh_tunnel() {
    log_info "Verificando túnel SSH para o worker AWS..."
    
    # Verificar se há processo ssh ativo para o worker
    if pgrep -f "ssh.*${WORKER_HOST}" > /dev/null; then
        log_success "Túnel SSH já está ativo"
        return 0
    else
        log_warning "Túnel SSH não está ativo"
        return 1
    fi
}

# Estabelecer túnel SSH
establish_ssh_tunnel() {
    log_info "Estabelecendo túnel SSH para o worker AWS..."
    
    # Verificar se a chave SSH existe
    if [ ! -f ~/.ssh/keyPrincipal.pem ]; then
        log_error "Chave SSH não encontrada: ~/.ssh/keyPrincipal.pem"
        exit 1
    fi
    
    # Verificar permissões da chave
    chmod 400 ~/.ssh/keyPrincipal.pem
    
    # Estabelecer túnel em background
    log_info "Conectando ao worker via SSH..."
    ssh -i ~/.ssh/keyPrincipal.pem -o StrictHostKeyChecking=no -fN ${WORKER_HOST}
    
    # Aguardar um momento para o túnel se estabelecer
    sleep 3
    
    # Verificar se o túnel foi estabelecido
    if check_ssh_tunnel; then
        log_success "Túnel SSH estabelecido com sucesso"
    else
        log_error "Falha ao estabelecer túnel SSH"
        exit 1
    fi
}

# Executar comando no worker via SSH
execute_on_worker() {
    local cmd="$1"
    log_info "Executando no worker: $cmd"
    ssh -i ~/.ssh/keyPrincipal.pem -o StrictHostKeyChecking=no ${WORKER_HOST} "$cmd"
}

# Login no Docker Hub no worker
docker_login_on_worker() {
    log_info "Fazendo login no Docker Hub no worker..."
    
    # Fazer login no Docker Hub
    execute_on_worker "echo '${DOCKER_PASS}' | docker login -u '${DOCKER_USER}' --password-stdin"
    
    if [ $? -eq 0 ]; then
        log_success "Login no Docker Hub realizado com sucesso"
    else
        log_error "Falha no login do Docker Hub"
        exit 1
    fi
}

# Build da imagem Docker no worker
build_docker_image() {
    log_info "Fazendo build da imagem Docker do frontend..."
    
    # Preparar diretório no worker e copiar código do frontend
    log_info "Preparando diretório no worker..."
    execute_on_worker "rm -rf ~/fiapx-frontend && mkdir -p ~/fiapx-frontend"
    
    log_info "Copiando código do frontend para o worker..."
    scp -i ~/.ssh/keyPrincipal.pem -r frontend/* ${WORKER_HOST}:~/fiapx-frontend/
    
    # Build da imagem
    execute_on_worker "cd ~/fiapx-frontend && docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
    
    if [ $? -eq 0 ]; then
        log_success "Build da imagem Docker concluído"
    else
        log_error "Falha no build da imagem Docker"
        exit 1
    fi
}

# Push da imagem para Docker Hub
push_docker_image() {
    log_info "Fazendo push da imagem para o Docker Hub..."
    
    execute_on_worker "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
    
    if [ $? -eq 0 ]; then
        log_success "Push da imagem Docker concluído"
    else
        log_error "Falha no push da imagem Docker"
        exit 1
    fi
}

# Deploy no Kubernetes
deploy_to_kubernetes() {
    log_info "Fazendo deploy no cluster Kubernetes..."
    
    # Verificar se o arquivo kubeconfig existe
    if [ ! -f "${KUBE_CONFIG}" ]; then
        log_error "Arquivo kubeconfig não encontrado: ${KUBE_CONFIG}"
        exit 1
    fi
    
    # Forçar pull da nova imagem e restart do deployment
    kubectl --kubeconfig=${KUBE_CONFIG} rollout restart deployment/frontend-deployment -n default
    
    if [ $? -eq 0 ]; then
        log_success "Deploy iniciado com sucesso"
        
        # Aguardar o rollout ser concluído
        log_info "Aguardando conclusão do rollout..."
        kubectl --kubeconfig=${KUBE_CONFIG} rollout status deployment/frontend-deployment -n default --timeout=300s
        
        if [ $? -eq 0 ]; then
            log_success "Deploy concluído com sucesso!"
        else
            log_warning "Deploy pode não ter sido concluído no tempo esperado"
        fi
    else
        log_error "Falha no deploy do Kubernetes"
        exit 1
    fi
}

# Verificar status do deployment
check_deployment_status() {
    log_info "Verificando status do deployment..."
    
    # Status dos pods
    kubectl --kubeconfig=${KUBE_CONFIG} get pods -l app=frontend -n default
    
    # Status do service
    kubectl --kubeconfig=${KUBE_CONFIG} get svc frontend-service -n default
    
    # Logs recentes
    log_info "Logs recentes do frontend:"
    kubectl --kubeconfig=${KUBE_CONFIG} logs -l app=frontend -n default --tail=10
}

# Função principal
main() {
    log_info "=== Iniciando deploy automatizado do frontend FIAP-X ==="
    
    # Verificar se estamos no diretório correto
    if [ ! -d "frontend" ]; then
        log_error "Diretório 'frontend' não encontrado. Execute o script a partir da raiz do projeto."
        exit 1
    fi
    
    # 1. Verificar/estabelecer túnel SSH
    if ! check_ssh_tunnel; then
        establish_ssh_tunnel
    fi
    
    # 2. Login no Docker Hub no worker
    docker_login_on_worker
    
    # 3. Build da imagem Docker
    build_docker_image
    
    # 4. Push da imagem
    push_docker_image
    
    # 5. Deploy no Kubernetes
    deploy_to_kubernetes
    
    # 6. Verificar status
    check_deployment_status
    
    log_success "=== Deploy automatizado concluído com sucesso! ==="
    log_info "O frontend foi atualizado e deve estar disponível em alguns minutos."
    log_info "Verifique o dashboard para confirmar que as estatísticas estão sendo exibidas corretamente."
}

# Tratar interrupção (Ctrl+C)
trap 'log_warning "Deploy interrompido pelo usuário"; exit 1' INT

# Executar função principal
main "$@"
