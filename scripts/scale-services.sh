#!/bin/bash

# Script para escalabilidade manual dos serviços FIAP-X
# Permite escalar rapidamente para suportar processamento paralelo

set -e

NAMESPACE="fiapx"
MAX_PROCESSING_PODS=5

echo "🚀 Script de Escalabilidade FIAP-X"
echo "=================================="

# Função para verificar status dos pods
check_pod_status() {
    echo "📊 Status atual dos pods:"
    kubectl get pods -n $NAMESPACE -l app=processing-service -o wide
    echo ""
}

# Função para escalar processing-service
scale_processing_service() {
    local replicas=$1
    
    if [ "$replicas" -gt $MAX_PROCESSING_PODS ]; then
        echo "⚠️  Limitando a $MAX_PROCESSING_PODS pods para otimizar recursos"
        replicas=$MAX_PROCESSING_PODS
    fi
    
    echo "🔧 Escalando processing-service para $replicas réplicas..."
    kubectl scale deployment processing-service -n $NAMESPACE --replicas=$replicas
    
    echo "⏳ Aguardando pods ficarem prontos..."
    kubectl wait --for=condition=ready pod -l app=processing-service -n $NAMESPACE --timeout=120s
    
    echo "✅ Processing-service escalado para $replicas pods"
}

# Função para escalar baseado na carga de trabalho
auto_scale_based_on_queue() {
    echo "🔍 Verificando carga da fila RabbitMQ..."
    
    # Simular verificação da fila (em produção seria via API do RabbitMQ)
    # Por enquanto, usar argumentos ou detecção automática
    
    local queue_size=${1:-0}
    local recommended_pods=1
    
    if [ "$queue_size" -gt 0 ]; then
        if [ "$queue_size" -le 2 ]; then
            recommended_pods=2
        elif [ "$queue_size" -le 4 ]; then
            recommended_pods=3
        elif [ "$queue_size" -le 6 ]; then
            recommended_pods=4
        else
            recommended_pods=5
        fi
        
        echo "📈 Fila com $queue_size vídeos → Recomendado: $recommended_pods pods"
        scale_processing_service $recommended_pods
    else
        echo "📉 Fila vazia → Mantendo configuração mínima"
    fi
}

# Função para teste de carga
test_parallel_processing() {
    echo "🧪 Preparando teste de processamento paralelo..."
    
    # Escalar para máximo
    scale_processing_service $MAX_PROCESSING_PODS
    
    echo "📋 Configuração para teste:"
    echo "   • $MAX_PROCESSING_PODS pods de processamento"
    echo "   • 1 vídeo por pod simultaneamente"
    echo "   • Fila RabbitMQ gerencia ordem"
    echo ""
    echo "🎯 Agora você pode enviar até $MAX_PROCESSING_PODS vídeos que serão processados em paralelo!"
}

# Menu principal
case "${1:-menu}" in
    "status")
        check_pod_status
        ;;
    "scale")
        if [ -z "$2" ]; then
            echo "❌ Uso: $0 scale <número_de_pods>"
            exit 1
        fi
        scale_processing_service $2
        ;;
    "auto")
        auto_scale_based_on_queue $2
        ;;
    "test")
        test_parallel_processing
        ;;
    "min")
        echo "📉 Configurando para carga mínima..."
        scale_processing_service 1
        ;;
    "max")
        echo "📈 Configurando para carga máxima..."
        scale_processing_service $MAX_PROCESSING_PODS
        ;;
    "menu"|*)
        echo "Uso: $0 <comando> [argumentos]"
        echo ""
        echo "Comandos disponíveis:"
        echo "  status              - Mostra status atual dos pods"
        echo "  scale <pods>        - Escala para número específico de pods"
        echo "  auto [queue_size]   - Escala automaticamente baseado na fila"
        echo "  test                - Configura para teste de paralelismo"
        echo "  min                 - Configura para carga mínima (1 pod)"
        echo "  max                 - Configura para carga máxima ($MAX_PROCESSING_PODS pods)"
        echo ""
        echo "Exemplos:"
        echo "  $0 scale 3          # Escala para 3 pods"
        echo "  $0 auto 5           # Escala baseado em 5 vídeos na fila"
        echo "  $0 test             # Prepara para teste paralelo"
        ;;
esac
