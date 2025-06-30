#!/bin/bash

# Script para deploy da arquitetura escalável
# Configura todos os componentes para suportar processamento paralelo

set -e

NAMESPACE="fiapx"
CLUSTER_IP="15.229.40.206"

echo "🚀 Deploy da Arquitetura Escalável FIAP-X"
echo "=========================================="

# Função para verificar se namespace existe
ensure_namespace() {
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        echo "📦 Criando namespace $NAMESPACE..."
        kubectl create namespace $NAMESPACE
    else
        echo "✅ Namespace $NAMESPACE já existe"
    fi
}

# Função para aplicar configurações
apply_configs() {
    echo "🔧 Aplicando configurações de escalabilidade..."
    
    # RabbitMQ com configurações para múltiplos consumers
    echo "  📡 Configurando RabbitMQ..."
    kubectl apply -f infrastructure/kubernetes/rabbitmq/rabbitmq.yaml
    
    # Processing Service com HPA
    echo "  ⚙️  Configurando Processing Service com HPA..."
    kubectl apply -f infrastructure/kubernetes/processing-service/processing-service.yaml
    
    echo "⏳ Aguardando serviços ficarem prontos..."
    kubectl wait --for=condition=ready pod -l app=rabbitmq -n $NAMESPACE --timeout=180s
    kubectl wait --for=condition=ready pod -l app=processing-service -n $NAMESPACE --timeout=180s
}

# Função para verificar HPA
check_hpa() {
    echo "📊 Verificando HorizontalPodAutoscaler..."
    kubectl get hpa -n $NAMESPACE
    echo ""
    echo "📋 Detalhes do HPA:"
    kubectl describe hpa processing-service-hpa -n $NAMESPACE
}

# Função para verificar métricas
check_metrics() {
    echo "📈 Verificando métricas dos pods..."
    kubectl top pods -n $NAMESPACE --containers 2>/dev/null || echo "⚠️  Metrics server pode não estar disponível"
}

# Função para testar escalabilidade
test_scalability() {
    echo "🧪 Testando escalabilidade..."
    
    echo "1. Escalando para máximo (5 pods)..."
    ./scripts/scale-services.sh max
    
    echo "2. Verificando status..."
    ./scripts/scale-services.sh status
    
    echo "3. Testando HPA..."
    check_hpa
}

# Função para criar serviço NodePort temporário para testes
create_test_nodeport() {
    echo "🌐 Criando serviço NodePort para testes..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: processing-service-nodeport
  namespace: fiapx
spec:
  type: NodePort
  selector:
    app: processing-service
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30084
EOF
    
    echo "✅ Processing Service disponível em: http://$CLUSTER_IP:30084/health"
}

# Função para configurar monitoramento da fila
setup_queue_monitoring() {
    echo "📊 Configurando monitoramento da fila..."
    
    # Script para monitorar fila do RabbitMQ
    cat <<'EOF' > scripts/monitor-queue.sh
#!/bin/bash

NAMESPACE="fiapx"
CLUSTER_IP="15.229.40.206"

echo "📊 Monitor da Fila RabbitMQ"
echo "========================="

while true; do
    echo -n "$(date '+%H:%M:%S') - "
    
    # Verificar pods de processamento
    PODS=$(kubectl get pods -n $NAMESPACE -l app=processing-service --no-headers | wc -l)
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=processing-service --no-headers | grep Running | wc -l)
    
    echo "Processing Pods: $READY_PODS/$PODS ready"
    
    sleep 5
done
EOF
    
    chmod +x scripts/monitor-queue.sh
    echo "✅ Monitor criado: ./scripts/monitor-queue.sh"
}

# Menu principal
case "${1:-deploy}" in
    "deploy")
        ensure_namespace
        apply_configs
        check_hpa
        setup_queue_monitoring
        echo ""
        echo "🎉 Deploy da arquitetura escalável concluído!"
        echo ""
        echo "📋 Próximos passos:"
        echo "  1. ./scripts/scale-services.sh test     # Testar paralelismo"
        echo "  2. ./scripts/monitor-queue.sh           # Monitorar fila"
        echo "  3. Enviar múltiplos vídeos via frontend"
        ;;
    "test")
        test_scalability
        ;;
    "nodeport")
        create_test_nodeport
        ;;
    "monitor")
        setup_queue_monitoring
        ;;
    "status")
        echo "📊 Status da arquitetura escalável:"
        echo ""
        kubectl get pods -n $NAMESPACE -l app=processing-service -o wide
        echo ""
        kubectl get hpa -n $NAMESPACE
        ;;
    *)
        echo "Uso: $0 <comando>"
        echo ""
        echo "Comandos disponíveis:"
        echo "  deploy     - Deploy completo da arquitetura escalável"
        echo "  test       - Teste de escalabilidade"
        echo "  nodeport   - Criar NodePort para testes"
        echo "  monitor    - Configurar monitoramento"
        echo "  status     - Status atual da arquitetura"
        ;;
esac
