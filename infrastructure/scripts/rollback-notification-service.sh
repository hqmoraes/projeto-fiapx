#!/bin/bash

# Script para rollback do notification-service
# Uso: ./rollback-notification-service.sh [--to-revision N] [--namespace fiapx]

set -e

# Configurações padrão
NAMESPACE="fiapx"
SERVICE_NAME="notification-service"
TO_REVISION=""

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --to-revision)
            TO_REVISION="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Uso: $0 [--to-revision N] [--namespace NAMESPACE]"
            echo ""
            echo "Opções:"
            echo "  --to-revision  Revisão específica para rollback (opcional)"
            echo "  --namespace    Namespace do Kubernetes (padrão: fiapx)"
            echo "  -h, --help     Mostra esta ajuda"
            echo ""
            echo "Exemplos:"
            echo "  $0                           # Rollback para revisão anterior"
            echo "  $0 --to-revision 5           # Rollback para revisão específica"
            echo "  $0 --namespace production    # Rollback em namespace específico"
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

# Verificar dependências
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

# Verificar se o deployment existe
if ! kubectl get deployment $SERVICE_NAME -n $NAMESPACE >/dev/null 2>&1; then
    print_color $RED "❌ Deployment '$SERVICE_NAME' não encontrado no namespace '$NAMESPACE'."
    exit 1
fi

print_color $BLUE "🔄 Iniciando rollback do Notification Service..."
echo ""

# Mostrar revisões disponíveis
print_color $BLUE "📋 Revisões disponíveis:"
kubectl rollout history deployment/$SERVICE_NAME -n $NAMESPACE

echo ""

# Obter status atual antes do rollback
print_color $BLUE "📊 Status atual antes do rollback:"
kubectl get deployment $SERVICE_NAME -n $NAMESPACE -o wide
kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME

echo ""

# Executar rollback
if [ -n "$TO_REVISION" ]; then
    print_color $YELLOW "⏪ Fazendo rollback para revisão $TO_REVISION..."
    kubectl rollout undo deployment/$SERVICE_NAME --to-revision=$TO_REVISION -n $NAMESPACE
else
    print_color $YELLOW "⏪ Fazendo rollback para revisão anterior..."
    kubectl rollout undo deployment/$SERVICE_NAME -n $NAMESPACE
fi

# Aguardar o rollback
print_color $YELLOW "⏳ Aguardando conclusão do rollback..."
kubectl rollout status deployment/$SERVICE_NAME -n $NAMESPACE --timeout=300s

# Verificar status após rollback
echo ""
print_color $BLUE "📊 Status após rollback:"
kubectl get deployment $SERVICE_NAME -n $NAMESPACE -o wide
kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME

# Verificar se os pods estão ready
echo ""
print_color $YELLOW "⏳ Aguardando pods ficarem ready..."
kubectl wait --for=condition=ready pod -l app=$SERVICE_NAME -n $NAMESPACE --timeout=120s

# Verificar logs para garantir que está funcionando
echo ""
print_color $BLUE "📋 Logs após rollback (últimas 20 linhas):"
kubectl logs -n $NAMESPACE -l app=$SERVICE_NAME --tail=20

# Health check final
echo ""
print_color $BLUE "💚 Health Check Final:"
PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME -o jsonpath='{.items[*].metadata.name}')

if [ -n "$PODS" ]; then
    for pod in $PODS; do
        STATUS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
        READY=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        if [ "$STATUS" = "Running" ] && [ "$READY" = "True" ]; then
            print_color $GREEN "✅ $pod: Running and Ready"
        else
            print_color $RED "❌ $pod: Status=$STATUS, Ready=$READY"
        fi
    done
else
    print_color $RED "❌ Nenhum pod encontrado após rollback"
    exit 1
fi

# Teste básico de conectividade
echo ""
print_color $BLUE "🔍 Teste de conectividade:"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
    kubectl exec -n $NAMESPACE $POD_NAME -- ps aux | grep notification-service >/dev/null && {
        print_color $GREEN "✅ Processo notification-service está rodando"
    } || {
        print_color $RED "❌ Processo notification-service não encontrado"
    }
else
    print_color $RED "❌ Nenhum pod disponível para teste"
fi

echo ""
print_color $GREEN "🎉 Rollback concluído com sucesso!"
echo ""
print_color $BLUE "📋 Resumo:"
echo "- Namespace: $NAMESPACE"
echo "- Service: $SERVICE_NAME"
if [ -n "$TO_REVISION" ]; then
    echo "- Rollback para revisão: $TO_REVISION"
else
    echo "- Rollback para revisão: anterior"
fi
echo ""
print_color $BLUE "💡 Comandos úteis para monitoramento:"
echo "- Monitorar pods: kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME -w"
echo "- Ver logs: kubectl logs -n $NAMESPACE -l app=$SERVICE_NAME -f"
echo "- Ver histórico: kubectl rollout history deployment/$SERVICE_NAME -n $NAMESPACE"
echo ""
print_color $YELLOW "⚠️  Lembre-se de verificar se o rollback resolveu o problema e considere"
print_color $YELLOW "   investigar a causa raiz do problema na versão anterior."
