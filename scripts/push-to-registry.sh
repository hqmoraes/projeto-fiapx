#!/bin/bash

# Script para fazer push das imagens para o registry local
# Autor: GitHub Copilot
# Data: 26/06/2025

echo "🚀 Configurando registry local e fazendo push das imagens..."

# Verificar se o kubectl está configurado
if ! kubectl --kubeconfig=kubeconfig.yaml get pods -n fiapx &>/dev/null; then
    echo "❌ Erro: kubectl não está configurado ou cluster não acessível"
    exit 1
fi

# Aguardar registry estar pronto
echo "⏳ Aguardando registry estar pronto..."
kubectl --kubeconfig=kubeconfig.yaml wait --for=condition=ready pod -l app=docker-registry -n fiapx --timeout=60s

# Obter IP do registry
REGISTRY_IP=$(kubectl --kubeconfig=kubeconfig.yaml get svc docker-registry -n fiapx -o jsonpath='{.spec.clusterIP}')
REGISTRY_URL="${REGISTRY_IP}:5000"

echo "🔍 Registry URL: ${REGISTRY_URL}"

# Função para fazer tag e push da imagem
push_image() {
    local service_name=$1
    local local_tag="fiapx/${service_name}:latest"
    local registry_tag="${REGISTRY_URL}/fiapx/${service_name}:latest"
    
    echo "📦 Processando ${service_name}..."
    
    # Verificar se a imagem local existe
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "${local_tag}"; then
        echo "  ✅ Imagem local encontrada: ${local_tag}"
        
        # Tag para o registry local
        docker tag "${local_tag}" "${registry_tag}"
        echo "  🏷️  Tag criada: ${registry_tag}"
        
        # Push para o registry (via port-forward)
        echo "  ⬆️  Fazendo push da imagem..."
        
        # Fazer port-forward do registry
        kubectl --kubeconfig=kubeconfig.yaml port-forward svc/docker-registry 5000:5000 -n fiapx &
        PORT_FORWARD_PID=$!
        sleep 3
        
        # Push da imagem
        if docker push "localhost:5000/fiapx/${service_name}:latest"; then
            echo "  ✅ Push realizado com sucesso para ${service_name}"
        else
            echo "  ❌ Erro no push para ${service_name}"
        fi
        
        # Parar port-forward
        kill $PORT_FORWARD_PID 2>/dev/null || true
        
    else
        echo "  ❌ Imagem local não encontrada: ${local_tag}"
        echo "  💡 Execute: cd ${service_name} && docker build -t ${local_tag} ."
    fi
    
    echo ""
}

# Lista de serviços para fazer push
services=("auth-service" "upload-service" "processing-service" "storage-service")

# Fazer push de cada serviço
for service in "${services[@]}"; do
    push_image "$service"
done

echo "🎉 Processo de push concluído!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Atualize os deployments para usar localhost:5000/fiapx/[service]:latest"
echo "   2. Configure imagePullPolicy: IfNotPresent"
echo "   3. Aplique os manifestos atualizados"
