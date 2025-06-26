#!/bin/bash

# Script para configurar túnel SSH direto para o cluster Kubernetes
# Autor: GitHub Copilot
# Data: 26 de junho de 2025

# Constantes
REMOTE_HOST="worker.wecando.click"
REMOTE_USER="ubuntu"
SSH_KEY="/home/hqmoraes/.ssh/keyPrincipal.pem"
KUBE_CONFIG="/home/hqmoraes/.kube/config"

# Obter o IP interno do servidor Kubernetes
get_kubernetes_ip() {
    local k8s_ip=$(ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "grep server ~/.kube/config | awk '{print \$2}' | cut -d/ -f3 | cut -d: -f1")
    echo "$k8s_ip"
}

# Inicia o túnel SSH
start_tunnel() {
    local k8s_ip=$(get_kubernetes_ip)
    if [ -z "$k8s_ip" ]; then
        echo "❌ Não foi possível obter o IP do servidor Kubernetes."
        exit 1
    fi
    
    echo "🔄 Iniciando túnel SSH para o cluster Kubernetes ($k8s_ip:6443)..."
    
    # Encerramos qualquer túnel existente
    pkill -f "ssh -i $SSH_KEY -L 6443:$k8s_ip:6443 -N $REMOTE_USER@$REMOTE_HOST" || true
    
    # Iniciamos um novo túnel
    ssh -i "$SSH_KEY" -L 6443:"$k8s_ip":6443 -N "$REMOTE_USER@$REMOTE_HOST" &
    
    # Armazenamos o PID do processo SSH
    tunnel_pid=$!
    
    # Verificamos se o processo está em execução
    if ps -p $tunnel_pid > /dev/null; then
        echo "✅ Túnel SSH estabelecido com sucesso! (PID: $tunnel_pid)"
        echo "$tunnel_pid" > /tmp/k8s-tunnel.pid
    else
        echo "❌ Falha ao estabelecer túnel SSH."
        exit 1
    fi
}

# Encerra o túnel SSH
stop_tunnel() {
    echo "🔄 Encerrando túnel SSH..."
    if [ -f /tmp/k8s-tunnel.pid ]; then
        pid=$(cat /tmp/k8s-tunnel.pid)
        kill $pid 2>/dev/null || true
        rm -f /tmp/k8s-tunnel.pid
        echo "✅ Túnel SSH encerrado com sucesso!"
    else
        pkill -f "ssh -i $SSH_KEY -L 6443:.* -N $REMOTE_USER@$REMOTE_HOST" || true
        echo "⚠️ Túnel SSH encerrado, mas não encontrado arquivo PID."
    fi
}

# Configura o kubeconfig para usar o localhost
configure_kubeconfig() {
    echo "🔄 Configurando arquivo kubeconfig para usar o túnel SSH..."
    
    # Verifica se temos o arquivo de configuração remoto
    if ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "test -f ~/.kube/config"; then
        # Copia o arquivo de configuração remoto
        ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "cat ~/.kube/config" > "$KUBE_CONFIG"
        
        # Modifica o arquivo para usar o localhost
        sed -i "s|server: https://.*|server: https://localhost:6443|g" "$KUBE_CONFIG"
        sed -i "/certificate-authority-data:/a\\    insecure-skip-tls-verify: true" "$KUBE_CONFIG"
        
        echo "✅ Arquivo kubeconfig configurado com sucesso!"
    else
        echo "❌ Arquivo de configuração Kubernetes não encontrado no servidor remoto."
        exit 1
    fi
}

# Verifica a conexão com o cluster Kubernetes
check_connection() {
    echo "🔄 Verificando conexão com o cluster Kubernetes..."
    export KUBECONFIG="$KUBE_CONFIG"
    
    # Esperamos um pouco para o túnel estabelecer
    sleep 3
    
    # Tentamos obter informações do cluster
    kubectl cluster-info
    if [ $? -eq 0 ]; then
        echo "✅ Conexão com o cluster Kubernetes estabelecida com sucesso!"
        return 0
    else
        echo "❌ Falha ao conectar ao cluster Kubernetes."
        echo "   Verificando detalhes da conexão..."
        
        # Verificamos se o túnel está funcionando
        nc -zv localhost 6443
        
        # Verificamos detalhes da conexão
        kubectl cluster-info dump --output-directory=/tmp/k8s-debug
        
        return 1
    fi
}

# Função principal
main() {
    echo "🚀 Configurando conexão com o cluster Kubernetes em $REMOTE_HOST"
    
    # Processa argumentos de linha de comando
    if [ "$1" == "stop" ]; then
        stop_tunnel
        exit 0
    fi
    
    # Configuramos o kubeconfig
    configure_kubeconfig
    
    # Iniciamos o túnel SSH
    start_tunnel
    
    # Verificamos a conexão com o cluster
    if check_connection; then
        echo "🎉 Configuração concluída! Você pode usar o kubectl normalmente agora."
        echo "   Para usar o kubectl, execute: export KUBECONFIG=$KUBE_CONFIG"
        echo ""
        echo "   Para encerrar o túnel SSH, execute: $0 stop"
    else
        echo "⚠️ A conexão com o cluster Kubernetes falhou."
        echo "   Verifique as configurações do servidor e tente novamente."
        stop_tunnel
        exit 1
    fi
}

# Executa a função principal com os argumentos passados
main "$@"
