#!/bin/bash

# Script para monitorar o notification-service em produção
# Uso: ./monitor-notification-service.sh [--watch] [--namespace fiapx]

set -e

# Configurações padrão
NAMESPACE="fiapx"
SERVICE_NAME="notification-service"
WATCH_MODE=false

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Uso: $0 [--watch] [--namespace NAMESPACE]"
            echo ""
            echo "Opções:"
            echo "  --watch        Monitora continuamente (modo watch)"
            echo "  --namespace    Namespace do Kubernetes (padrão: fiapx)"
            echo "  -h, --help     Mostra esta ajuda"
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            exit 1
            ;;
    esac
done

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir com cor
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Função para verificar status do serviço
check_service_status() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Verificando status do Notification Service..."
    echo "=================================================="
    
    # Verificar deployment
    print_color $BLUE "📦 Deployment Status:"
    kubectl get deployment $SERVICE_NAME -n $NAMESPACE -o wide 2>/dev/null || {
        print_color $RED "❌ Deployment não encontrado"
        return 1
    }
    
    echo ""
    
    # Verificar pods
    print_color $BLUE "🚀 Pods Status:"
    kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME -o wide 2>/dev/null || {
        print_color $RED "❌ Nenhum pod encontrado"
    }
    
    echo ""
    
    # Verificar service
    print_color $BLUE "🌐 Service Status:"
    kubectl get service $SERVICE_NAME -n $NAMESPACE 2>/dev/null || {
        print_color $RED "❌ Service não encontrado"
    }
    
    echo ""
    
    # Verificar recursos
    print_color $BLUE "📊 Resource Usage:"
    kubectl top pods -n $NAMESPACE -l app=$SERVICE_NAME 2>/dev/null || {
        print_color $YELLOW "⚠️  Metrics não disponíveis (metrics-server necessário)"
    }
    
    echo ""
    
    # Verificar logs recentes
    print_color $BLUE "📋 Recent Logs (last 10 lines):"
    kubectl logs -n $NAMESPACE -l app=$SERVICE_NAME --tail=10 2>/dev/null || {
        print_color $RED "❌ Não foi possível obter logs"
    }
    
    echo ""
    
    # Verificar events
    print_color $BLUE "📅 Recent Events:"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$SERVICE_NAME --sort-by='.lastTimestamp' | tail -5 2>/dev/null || {
        print_color $YELLOW "⚠️  Nenhum event recente encontrado"
    }
    
    echo ""
    
    # Health check dos pods
    print_color $BLUE "💚 Pod Health Check:"
    PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -n "$PODS" ]; then
        for pod in $PODS; do
            STATUS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
            READY=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            
            if [ "$STATUS" = "Running" ] && [ "$READY" = "True" ]; then
                print_color $GREEN "✅ $pod: Running and Ready"
            else
                print_color $RED "❌ $pod: Status=$STATUS, Ready=$READY"
            fi
        done
    else
        print_color $RED "❌ Nenhum pod encontrado"
    fi
    
    echo ""
    
    # Verificar secrets
    print_color $BLUE "🔐 Secrets Check:"
    kubectl get secret ses-email-secrets -n $NAMESPACE >/dev/null 2>&1 && {
        print_color $GREEN "✅ SES Email Secrets encontrado"
    } || {
        print_color $RED "❌ SES Email Secrets não encontrado"
    }
    
    echo ""
    
    # Verificar conectividade com RabbitMQ
    print_color $BLUE "🐰 RabbitMQ Connectivity:"
    kubectl get service rabbitmq -n $NAMESPACE >/dev/null 2>&1 && {
        print_color $GREEN "✅ RabbitMQ service encontrado"
    } || {
        print_color $RED "❌ RabbitMQ service não encontrado"
    }
    
    echo "=================================================="
    echo ""
}

# Função para monitoramento contínuo
continuous_monitor() {
    print_color $YELLOW "🔄 Iniciando monitoramento contínuo (Ctrl+C para parar)..."
    echo ""
    
    while true; do
        clear
        check_service_status
        sleep 30
    done
}

# Verificar se kubectl está disponível
if ! command -v kubectl >/dev/null 2>&1; then
    print_color $RED "❌ kubectl não encontrado. Instale o kubectl primeiro."
    exit 1
fi

# Verificar conectividade com o cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_color $RED "❌ Não foi possível conectar ao cluster Kubernetes."
    exit 1
fi

# Verificar se o namespace existe
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    print_color $RED "❌ Namespace '$NAMESPACE' não existe."
    exit 1
fi

print_color $GREEN "🎯 Monitorando Notification Service no namespace '$NAMESPACE'"
echo ""

# Executar em modo watch ou única vez
if [ "$WATCH_MODE" = true ]; then
    continuous_monitor
else
    check_service_status
    
    echo "💡 Para monitoramento contínuo, use: $0 --watch"
    echo "💡 Para diferentes namespace, use: $0 --namespace SEU_NAMESPACE"
fi
