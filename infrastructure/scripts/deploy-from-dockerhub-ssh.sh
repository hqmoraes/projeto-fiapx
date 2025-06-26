#!/bin/bash

# Deploy microsserviços usando imagens do Docker Hub via SSH
# Este script executa os comandos kubectl diretamente no servidor remoto

set -e

echo "🚀 Iniciando deploy dos microsserviços usando imagens do Docker Hub via SSH..."

# Configurações
REMOTE_HOST="worker.wecando.click"
REMOTE_USER="ubuntu"
SSH_KEY="~/.ssh/keyPrincipal.pem"

# Função para executar comando no servidor remoto
remote_kubectl() {
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "$@"
}

# Verificar conectividade com o cluster
echo "📋 Verificando conectividade com o cluster..."
if ! remote_kubectl "kubectl get nodes"; then
    echo "❌ Erro: Não foi possível conectar ao cluster Kubernetes"
    exit 1
fi

# Verificar se o namespace existe
echo "📋 Verificando namespace fiapx..."
if ! remote_kubectl "kubectl get namespace fiapx" >/dev/null 2>&1; then
    echo "⚠️  Namespace fiapx não encontrado, criando..."
    remote_kubectl "kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: fiapx
EOF"
fi

# Copiar manifestos para o servidor remoto
echo "📋 Copiando manifestos para o servidor remoto..."
scp -i ~/.ssh/keyPrincipal.pem -r ../kubernetes/ ubuntu@worker.wecando.click:~/

# Verificar status dos serviços de infraestrutura
echo "📋 Verificando serviços de infraestrutura..."
remote_kubectl "kubectl get pods -n fiapx | grep -E '(postgres|redis|rabbitmq|minio)'"

# Deploy dos microsserviços na ordem correta
echo "🔄 Atualizando auth-service..."
remote_kubectl "kubectl apply -f ~/kubernetes/auth-service/auth-service.yaml -n fiapx"

echo "🔄 Atualizando upload-service..."
remote_kubectl "kubectl apply -f ~/kubernetes/upload-service/upload-service.yaml -n fiapx"

echo "🔄 Atualizando processing-service..."
remote_kubectl "kubectl apply -f ~/kubernetes/processing-service/processing-service.yaml -n fiapx"

echo "🔄 Atualizando storage-service..."
remote_kubectl "kubectl apply -f ~/kubernetes/storage-service/storage-service.yaml -n fiapx"

# Aguardar os pods ficarem prontos
echo "⏳ Aguardando pods ficarem prontos..."
sleep 15

# Verificar status do deployment
echo "📊 Status dos deployments:"
remote_kubectl "kubectl get deployments -n fiapx"

echo "📊 Status dos pods:"
remote_kubectl "kubectl get pods -n fiapx -o wide"

echo "📊 Status dos serviços:"
remote_kubectl "kubectl get services -n fiapx"

# Verificar se há pods com problemas
echo "🔍 Verificando pods com problemas..."
if remote_kubectl "kubectl get pods -n fiapx | grep -E '(Error|CrashLoopBackOff|ImagePullBackOff|Pending)'"; then
    echo "⚠️  Alguns pods apresentam problemas. Verificando detalhes..."
    
    # Mostrar detalhes dos pods com problemas
    problem_pods=$(remote_kubectl "kubectl get pods -n fiapx | grep -E '(Error|CrashLoopBackOff|ImagePullBackOff|Pending)' | awk '{print \$1}'")
    for pod in $problem_pods; do
        echo "🔍 Detalhes do pod $pod:"
        remote_kubectl "kubectl describe pod $pod -n fiapx | tail -20"
        echo "---"
    done
else
    echo "✅ Todos os pods estão funcionando corretamente!"
fi

# Verificar logs dos microsserviços (últimas 5 linhas)
echo "📋 Últimos logs dos microsserviços:"
for service in auth-service upload-service processing-service storage-service; do
    echo "🔍 Logs do $service:"
    remote_kubectl "kubectl logs -l app=$service -n fiapx --tail=5 2>/dev/null || echo 'Pod não encontrado ou sem logs'"
    echo "---"
done

echo "✅ Deploy concluído! Os microsserviços estão usando as imagens do Docker Hub."
echo "🌐 Imagens utilizadas:"
echo "  - hmoraes/auth-service:latest"
echo "  - hmoraes/upload-service:latest"
echo "  - hmoraes/processing-service:latest"
echo "  - hmoraes/storage-service:latest"
