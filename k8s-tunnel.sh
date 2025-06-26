#!/bin/bash

# Script para configurar túnel SSH para o cluster Kubernetes
# Autor: GitHub Copilot
# Data: 26 de junho de 2025

# Constantes
REMOTE_HOST="worker.wecando.click"
REMOTE_USER="ubuntu"
SSH_KEY="/home/hqmoraes/.ssh/keyPrincipal.pem"
KUBE_CONFIG="/home/hqmoraes/Documents/fiap/projeto-fiapx/kubeconfig.yaml"
LOCAL_PORT=6443
REMOTE_PORT=6443

# Verifica se o túnel já está ativo
check_tunnel() {
    pgrep -f "ssh -f -N k8s-tunnel" > /dev/null
    return $?
}

# Inicia o túnel SSH
start_tunnel() {
    echo "🔄 Iniciando túnel SSH para o cluster Kubernetes..."
    ssh -f -N k8s-tunnel
    if [ $? -eq 0 ]; then
        echo "✅ Túnel SSH estabelecido com sucesso!"
    else
        echo "❌ Falha ao estabelecer túnel SSH."
        exit 1
    fi
}

# Encerra o túnel SSH
stop_tunnel() {
    echo "🔄 Encerrando túnel SSH..."
    pkill -f "ssh -f -N k8s-tunnel"
    if [ $? -eq 0 ]; then
        echo "✅ Túnel SSH encerrado com sucesso!"
    else
        echo "⚠️ Nenhum túnel SSH encontrado para encerrar."
    fi
}

# Verifica a conexão com o cluster Kubernetes
check_connection() {
    echo "🔄 Verificando conexão com o cluster Kubernetes..."
    export KUBECONFIG=$KUBE_CONFIG
    kubectl cluster-info
    if [ $? -eq 0 ]; then
        echo "✅ Conexão com o cluster Kubernetes estabelecida com sucesso!"
    else
        echo "❌ Falha ao conectar ao cluster Kubernetes."
        echo "   Verifique se o túnel SSH está ativo e se o arquivo kubeconfig está correto."
        exit 1
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
    
    # Verifica se o túnel já está ativo
    if check_tunnel; then
        echo "✅ Túnel SSH já está ativo."
    else
        start_tunnel
    fi
    
    # Verifica a conexão com o cluster
    check_connection
    
    echo "🎉 Configuração concluída! Você pode usar o kubectl normalmente agora."
    echo "   Para usar o kubectl, execute: export KUBECONFIG=$KUBE_CONFIG"
    echo ""
    echo "   Para encerrar o túnel SSH, execute: $0 stop"
}

# Executa a função principal com os argumentos passados
main "$@"
main
