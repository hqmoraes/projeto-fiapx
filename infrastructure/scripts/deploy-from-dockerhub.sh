#!/bin/bash

# Deploy microsserviços usando imagens do Docker Hub
# Este script aplica os manifestos atualizados que usam as imagens públicas

set -e

echo "🚀 Iniciando deploy dos microsserviços usando imagens do Docker Hub..."

# Configurar kubeconfig
export KUBECONFIG="/home/hqmoraes/Documents/fiap/projeto-fiapx/kubeconfig.yaml"

# Verificar conectividade com o cluster
echo "📋 Verificando conectividade com o cluster..."
if ! kubectl get nodes; then
    echo "❌ Erro: Não foi possível conectar ao cluster Kubernetes"
    echo "Verifique se o túnel SSH está ativo e o kubeconfig está correto"
    exit 1
fi

# Verificar se o namespace existe
echo "📋 Verificando namespace fiapx..."
if ! kubectl get namespace fiapx >/dev/null 2>&1; then
    echo "⚠️  Namespace fiapx não encontrado, criando..."
    kubectl apply -f ../kubernetes/namespace.yaml
fi

# Verificar status dos serviços de infraestrutura
echo "📋 Verificando serviços de infraestrutura..."
kubectl get pods -n fiapx | grep -E "(postgres|redis|rabbitmq|minio)"

# Deploy dos microsserviços na ordem correta
echo "🔄 Atualizando auth-service..."
kubectl apply -f ../kubernetes/auth-service/auth-service.yaml -n fiapx

echo "🔄 Atualizando upload-service..."
kubectl apply -f ../kubernetes/upload-service/upload-service.yaml -n fiapx

echo "🔄 Atualizando processing-service..."
kubectl apply -f ../kubernetes/processing-service/processing-service.yaml -n fiapx

echo "🔄 Atualizando storage-service..."
kubectl apply -f ../kubernetes/storage-service/storage-service.yaml -n fiapx

# Aguardar os pods ficarem prontos
echo "⏳ Aguardando pods ficarem prontos..."
sleep 10

# Verificar status do deployment
echo "📊 Status dos deployments:"
kubectl get deployments -n fiapx

echo "📊 Status dos pods:"
kubectl get pods -n fiapx -o wide

echo "📊 Status dos serviços:"
kubectl get services -n fiapx

# Verificar se há pods com problemas
echo "🔍 Verificando pods com problemas..."
if kubectl get pods -n fiapx | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)"; then
    echo "⚠️  Alguns pods apresentam problemas. Verificando detalhes..."
    
    # Mostrar detalhes dos pods com problemas
    for pod in $(kubectl get pods -n fiapx | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" | awk '{print $1}'); do
        echo "🔍 Detalhes do pod $pod:"
        kubectl describe pod $pod -n fiapx | tail -20
        echo "---"
    done
else
    echo "✅ Todos os pods estão funcionando corretamente!"
fi

# Verificar logs dos microsserviços (últimas 5 linhas)
echo "📋 Últimos logs dos microsserviços:"
for service in auth-service upload-service processing-service storage-service; do
    echo "🔍 Logs do $service:"
    kubectl logs -l app=$service -n fiapx --tail=5 2>/dev/null || echo "Pod não encontrado ou sem logs"
    echo "---"
done

echo "✅ Deploy concluído! Os microsserviços estão usando as imagens do Docker Hub."
echo "🌐 Imagens utilizadas:"
echo "  - hmoraes/auth-service:latest"
echo "  - hmoraes/upload-service:latest"
echo "  - hmoraes/processing-service:latest"
echo "  - hmoraes/storage-service:latest"
