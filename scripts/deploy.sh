#!/bin/bash

# Script para implantar no Kubernetes
# Autor: GitHub Copilot
# Data: 26/06/2025

# Definir namespace e configurações
NAMESPACE=${1:-fiapx}
ENVIRONMENT=${2:-dev}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-"docker.io"}
PROJECT_PREFIX=${PROJECT_PREFIX:-"fiapx"}

echo "🚀 Implantando aplicação no namespace '$NAMESPACE' para o ambiente '$ENVIRONMENT'..."
echo "🔄 Usando registry de containers: $DOCKER_REGISTRY"

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
kubectl cluster-info > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes. Verifique sua configuração."
    exit 1
fi

# Verificar e preparar ambiente Kubernetes usando check-k8s.sh
echo "🔄 Verificando e preparando ambiente Kubernetes..."
./scripts/check-k8s.sh $NAMESPACE

# Criar namespace se não existir
kubectl get namespace $NAMESPACE > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "📁 Criando namespace '$NAMESPACE'..."
    kubectl apply -f infrastructure/kubernetes/namespace.yaml
fi

# Aplicar ConfigMaps e Secrets
echo "🔑 Aplicando ConfigMaps e Secrets..."
# Procura e aplica todos os manifestos de secrets disponíveis
find infrastructure/kubernetes -name "*secret*.yaml" -type f -exec kubectl apply -f {} -n $NAMESPACE \;

# Aplicar Resource Quotas
echo "📊 Aplicando Resource Quotas..."
kubectl apply -f infrastructure/kubernetes/resource-quotas.yaml -n $NAMESPACE

# Implantar infraestrutura
echo "🏗️ Implantando serviços de infraestrutura..."
echo "🔄 Implantando PostgreSQL..."
kubectl apply -f infrastructure/kubernetes/postgres/ -n $NAMESPACE

echo "🔄 Implantando RabbitMQ..."
kubectl apply -f infrastructure/kubernetes/rabbitmq/ -n $NAMESPACE

echo "🔄 Implantando Redis..."
kubectl apply -f infrastructure/kubernetes/redis/ -n $NAMESPACE

echo "🔄 Implantando MinIO..."
kubectl apply -f infrastructure/kubernetes/minio/ -n $NAMESPACE

# Aguardar infraestrutura estar pronta
echo "⏳ Aguardando serviços de infraestrutura estarem prontos..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s || echo "⚠️ Timeout aguardando PostgreSQL. Continuando..."
kubectl wait --for=condition=ready pod -l app=rabbitmq -n $NAMESPACE --timeout=300s || echo "⚠️ Timeout aguardando RabbitMQ. Continuando..."
kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s || echo "⚠️ Timeout aguardando Redis. Continuando..."
kubectl wait --for=condition=ready pod -l app=minio -n $NAMESPACE --timeout=300s || echo "⚠️ Timeout aguardando MinIO. Continuando..."

# Processar templates Kubernetes substituindo variáveis
echo "� Processando templates Kubernetes..."
for file in $(find infrastructure/kubernetes -name "*.yaml" -type f); do
    mkdir -p /tmp/k8s-processed
    cat $file | sed "s|\${DOCKER_REGISTRY}|$DOCKER_REGISTRY|g" | \
               sed "s|\${PROJECT_PREFIX}|$PROJECT_PREFIX|g" | \
               sed "s|\${ENVIRONMENT}|$ENVIRONMENT|g" > /tmp/k8s-processed/$(basename $file)
done

# Implantar microsserviços em ordem hierárquica
echo "🚢 Implantando microsserviços..."

# 1. Primeiro serviço: Auth Service (mais fundamental)
echo "🔄 Implantando Auth Service..."
kubectl apply -f infrastructure/kubernetes/auth-service/ -n $NAMESPACE
echo "⏳ Aguardando Auth Service estar pronto..."
kubectl wait --for=condition=ready pod -l app=auth-service -n $NAMESPACE --timeout=300s || echo "⚠️ Timeout aguardando Auth Service. Continuando..."

# 2. Segundo serviço: Upload Service
echo "🔄 Implantando Upload Service..."
kubectl apply -f infrastructure/kubernetes/upload-service/ -n $NAMESPACE 2>/dev/null || echo "⚠️ Upload Service ainda não implementado."

# 3. Terceiro serviço: Processing Service
echo "🔄 Implantando Processing Service..."
kubectl apply -f infrastructure/kubernetes/processing-service/ -n $NAMESPACE 2>/dev/null || echo "⚠️ Processing Service ainda não implementado."

# 4. Quarto serviço: Storage Service
echo "🔄 Implantando Storage Service..."
kubectl apply -f infrastructure/kubernetes/storage-service/ -n $NAMESPACE 2>/dev/null || echo "⚠️ Storage Service ainda não implementado."

# 5. Por último: API Gateway
echo "🌐 Implantando API Gateway..."
kubectl apply -f infrastructure/kubernetes/api-gateway/ -n $NAMESPACE 2>/dev/null || echo "⚠️ API Gateway ainda não implementado."

# Implantar monitoramento
echo "📊 Implantando ferramentas de monitoramento..."
kubectl apply -f infrastructure/kubernetes/monitoring/ -n $NAMESPACE 2>/dev/null || echo "⚠️ Monitoring ainda não implementado."

# Mostrar status da implantação
echo "🔍 Status da implantação:"
kubectl get pods -n $NAMESPACE

# Obter endereço do Ingress (se existir)
echo "🔍 Verificando Ingress..."
kubectl get ingress -n $NAMESPACE 2>/dev/null
INGRESS_HOST=$(kubectl get ingress api-gateway-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl get ingress api-gateway-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
fi

echo "✅ Implantação concluída!"
echo ""
echo "Para acessar a aplicação:"
if [ -n "$INGRESS_HOST" ]; then
    echo "API: http://$INGRESS_HOST"
else
    echo "API: Configure seu Ingress ou use port-forward:"
    echo "kubectl port-forward svc/api-gateway -n $NAMESPACE 8080:8080"
fi
echo ""
echo "Para verificar os pods em execução:"
echo "kubectl get pods -n $NAMESPACE"
echo ""
echo "Para verificar os logs de um serviço:"
echo "kubectl logs deployment/auth-service -n $NAMESPACE"
