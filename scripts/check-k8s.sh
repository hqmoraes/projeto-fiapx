#!/bin/bash

# Script para verificar e preparar o ambiente Kubernetes
# Autor: GitHub Copilot
# Data: 26/06/2025

echo "🔍 Verificando e preparando o ambiente Kubernetes..."

# Verificar se o kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl não encontrado. Por favor, instale kubectl."
    exit 1
fi

# Configurar o túnel SSH para o cluster Kubernetes
echo "🔄 Configurando túnel SSH para o cluster Kubernetes..."
if [ -f "./setup-k8s-tunnel.sh" ]; then
    # Encerrar qualquer túnel existente
    ./setup-k8s-tunnel.sh stop 2>/dev/null || true
    
    # Iniciar novo túnel
    ./setup-k8s-tunnel.sh
    
    # Exportar o KUBECONFIG
    export KUBECONFIG="$(pwd)/kubeconfig.yaml"
else
    echo "❌ Script setup-k8s-tunnel.sh não encontrado. É obrigatório para acessar o cluster remoto."
    exit 1
fi

# Verificar a conexão com o cluster
echo "🔍 Verificando conexão com o cluster Kubernetes..."
kubectl cluster-info
if [ $? -ne 0 ]; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes. Verifique sua configuração."
    exit 1
fi

# Criar namespace fiapx se não existir
NAMESPACE=${1:-fiapx}
echo "🔄 Verificando namespace '$NAMESPACE'..."
kubectl get namespace $NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "📁 Criando namespace '$NAMESPACE'..."
    kubectl apply -f infrastructure/kubernetes/namespace.yaml
else
    echo "✅ Namespace '$NAMESPACE' já existe."
fi

# Verificar cotas e limites do namespace
echo "🔄 Verificando resource quotas para o namespace '$NAMESPACE'..."
kubectl get resourcequota -n $NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "📊 Aplicando resource quotas para o namespace '$NAMESPACE'..."
    kubectl apply -f infrastructure/kubernetes/resource-quotas.yaml -n $NAMESPACE
else
    echo "✅ Resource quotas já configuradas para o namespace '$NAMESPACE'."
fi

# Verificar se o contexto atual aponta para o cluster remoto
CURRENT_CONTEXT=$(kubectl config current-context)
echo "🔄 Contexto Kubernetes atual: $CURRENT_CONTEXT"

# Verificar nós do cluster
echo "🔍 Verificando nós do cluster Kubernetes..."
kubectl get nodes -o wide

# Verificar as versões das ferramentas disponíveis no cluster
echo "🔍 Verificando versões das ferramentas no cluster..."
echo "Kubernetes: $(kubectl version --short | grep 'Server Version' | awk '{print $3}')"

# Verificar se imagens de container podem ser puxadas
echo "🔄 Verificando acesso a registry de containers..."
kubectl run test-pull --image=nginx:alpine --restart=Never -n $NAMESPACE --dry-run=client -o yaml > /dev/null
if [ $? -ne 0 ]; then
    echo "⚠️ Pode haver problemas ao puxar imagens de container. Verifique a configuração do registry."
else
    echo "✅ Acesso a registry de containers parece estar ok."
fi

echo "✅ Ambiente Kubernetes verificado e preparado com sucesso!"
echo ""
echo "Para utilizar o kubectl com este cluster, utilize:"
echo "export KUBECONFIG=$(pwd)/kubeconfig.yaml"
echo ""
echo "Para implantar a aplicação, execute:"
echo "./scripts/deploy.sh $NAMESPACE"
