#!/bin/bash

# Script para configurar túnel SSH para o cluster Kubernetes
# Autor: GitHub Copilot
# Data: 26 de junho de 2025

# Constantes
REMOTE_HOST="worker.wecando.click"
REMOTE_USER="ubuntu"
SSH_KEY="$HOME/.ssh/keyPrincipal.pem"
KUBE_CONFIG_LOCAL="/home/hqmoraes/Documents/fiap/projeto-fiapx/kubeconfig.yaml"
LOCAL_PORT=6443

# Função para obter o endereço do servidor Kubernetes do arquivo kubeconfig remoto
get_k8s_server() {
    ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" \
        "grep 'server:' ~/.kube/config | head -n1 | awk '{print \$2}'" | tr -d '\r'
}

# Função para obter o endereço IP e porta do servidor Kubernetes
parse_server_url() {
    local server_url=$1
    # Remove https:// do início
    local url=${server_url#https://}
    # Separa host e porta
    local host=${url%:*}
    local port=${url#*:}
    echo "$host $port"
}

# Função para verificar se já existe um túnel SSH ativo
check_tunnel() {
    pgrep -f "ssh -i $SSH_KEY -L $LOCAL_PORT.*$REMOTE_HOST" > /dev/null
    return $?
}

# Função para iniciar o túnel SSH
start_tunnel() {
    local k8s_server=$(get_k8s_server)
    local server_info=$(parse_server_url "$k8s_server")
    local server_host=$(echo $server_info | cut -d' ' -f1)
    local server_port=$(echo $server_info | cut -d' ' -f2)
    
    echo "🔄 Servidor Kubernetes detectado: $server_host:$server_port"
    
    if [[ -z "$server_host" || -z "$server_port" ]]; then
        echo "❌ Não foi possível determinar o servidor Kubernetes. Verifique a configuração."
        exit 1
    fi
    
    # Mata qualquer túnel SSH existente
    if check_tunnel; then
        echo "⚠️ Túnel SSH já existe. Encerrando túnel antigo..."
        pkill -f "ssh -i $SSH_KEY -L $LOCAL_PORT.*$REMOTE_HOST"
        sleep 2
    fi
    
    echo "🔄 Iniciando túnel SSH para o cluster Kubernetes..."
    ssh -i "$SSH_KEY" -L "$LOCAL_PORT:$server_host:$server_port" -N "$REMOTE_USER@$REMOTE_HOST" &
    
    # Armazenar PID do túnel
    TUNNEL_PID=$!
    
    # Verificar se o processo está rodando
    if ps -p $TUNNEL_PID > /dev/null; then
        echo "✅ Túnel SSH estabelecido com sucesso! (PID: $TUNNEL_PID)"
        echo $TUNNEL_PID > /tmp/k8s_tunnel.pid
    else
        echo "❌ Falha ao estabelecer túnel SSH."
        exit 1
    fi
}

# Função para copiar e ajustar o arquivo kubeconfig
setup_kubeconfig() {
    echo "🔄 Copiando e ajustando o arquivo kubeconfig..."
    
    # Copiar o arquivo kubeconfig do servidor remoto
    ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" "cat ~/.kube/config" > "$KUBE_CONFIG_LOCAL"
    
    if [ ! -f "$KUBE_CONFIG_LOCAL" ]; then
        echo "❌ Falha ao copiar o arquivo kubeconfig."
        exit 1
    fi
    
    # Ajustar o servidor no arquivo kubeconfig para apontar para localhost
    local original_server=$(grep 'server:' "$KUBE_CONFIG_LOCAL" | head -n1 | awk '{print $2}')
    
    # Remover a linha de certificate-authority-data
    sed -i '/certificate-authority-data:/d' "$KUBE_CONFIG_LOCAL"
    
    # Modificar o servidor para localhost
    local modified_config=$(cat "$KUBE_CONFIG_LOCAL" | sed "s|$original_server|https://localhost:$LOCAL_PORT|g")
    
    # Adicionar a opção para ignorar verificação de TLS
    if ! grep -q "insecure-skip-tls-verify: true" "$KUBE_CONFIG_LOCAL"; then
        modified_config=$(echo "$modified_config" | sed "/server: https/a\\    insecure-skip-tls-verify: true")
    fi
    
    # Salvar as alterações de volta ao arquivo
    echo "$modified_config" > "$KUBE_CONFIG_LOCAL"
    
    echo "✅ Arquivo kubeconfig ajustado com sucesso!"
    echo "   Novo arquivo de configuração: $KUBE_CONFIG_LOCAL"
}

# Função para testar a conexão com o cluster Kubernetes
test_connection() {
    echo "🔄 Testando conexão com o cluster Kubernetes..."
    
    export KUBECONFIG="$KUBE_CONFIG_LOCAL"
    
    # Aguardar um pouco para o túnel ser estabelecido
    sleep 3
    
    # Testar a conexão
    kubectl cluster-info
    
    if [ $? -eq 0 ]; then
        echo "✅ Conexão com o cluster Kubernetes estabelecida com sucesso!"
        return 0
    else
        echo "❌ Falha ao conectar ao cluster Kubernetes."
        echo "   Verifique as configurações e tente novamente."
        return 1
    fi
}

# Função para encerrar o túnel SSH
stop_tunnel() {
    echo "🔄 Encerrando túnel SSH..."
    
    if [ -f "/tmp/k8s_tunnel.pid" ]; then
        PID=$(cat /tmp/k8s_tunnel.pid)
        kill $PID 2>/dev/null
        rm -f /tmp/k8s_tunnel.pid
    fi
    
    pkill -f "ssh -i $SSH_KEY -L $LOCAL_PORT.*$REMOTE_HOST"
    
    echo "✅ Túnel SSH encerrado."
}

# Função principal
main() {
    echo "🚀 Configurando conexão com o cluster Kubernetes em $REMOTE_HOST"
    
    # Processar argumentos
    if [ "$1" == "stop" ]; then
        stop_tunnel
        exit 0
    fi
    
    # Iniciar o túnel SSH
    start_tunnel
    
    # Configurar o arquivo kubeconfig
    setup_kubeconfig
    
    # Testar a conexão
    if test_connection; then
        echo ""
        echo "🎉 Configuração concluída! Você pode usar o kubectl com o seguinte comando:"
        echo "   export KUBECONFIG=$KUBE_CONFIG_LOCAL"
        echo ""
        echo "📝 Para encerrar o túnel SSH, execute:"
        echo "   $0 stop"
    else
        stop_tunnel
        exit 1
    fi
}

# Executar a função principal
main "$@"
