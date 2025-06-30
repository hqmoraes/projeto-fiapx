#!/bin/bash

# Script de Deploy Completo na AWS - Observabilidade
# Projeto FIAP-X - Sistema de Processamento de Vídeos

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 DEPLOY OBSERVABILIDADE NA AWS - Projeto FIAP-X${NC}"
echo ""

# Função para validar pré-requisitos
validate_prerequisites() {
    echo -e "${YELLOW}📋 Validando pré-requisitos...${NC}"
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl não encontrado${NC}"
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ helm não encontrado${NC}"
        exit 1
    fi
    
    # Verificar conexão com cluster
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Não conectado ao cluster Kubernetes${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Pré-requisitos validados${NC}"
}

# Função para aplicar ServiceMonitor
apply_servicemonitor() {
    echo -e "${YELLOW}📊 Aplicando ServiceMonitor...${NC}"
    
    kubectl apply -f infrastructure/kubernetes/processing-service/processing-service-servicemonitor.yaml
    
    echo -e "${GREEN}✅ ServiceMonitor aplicado${NC}"
}

# Função para instalar Prometheus e Grafana
install_monitoring_stack() {
    echo -e "${YELLOW}📈 Instalando stack de monitoramento...${NC}"
    
    # Adicionar repositórios Helm
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Verificar se já está instalado
    if helm list -n monitoring | grep -q prometheus; then
        echo -e "${BLUE}ℹ️  Prometheus já instalado, fazendo upgrade...${NC}"
        helm upgrade prometheus prometheus-community/kube-prometheus-stack --namespace monitoring
    else
        echo -e "${BLUE}🔧 Instalando Prometheus e Grafana...${NC}"
        helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
    fi
    
    echo -e "${GREEN}✅ Stack de monitoramento instalado${NC}"
}

# Função para aguardar pods
wait_for_pods() {
    echo -e "${YELLOW}⏳ Aguardando pods ficarem prontos...${NC}"
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
    
    echo -e "${GREEN}✅ Pods prontos${NC}"
}

# Função para atualizar processing-service
update_processing_service() {
    echo -e "${YELLOW}🔄 Atualizando processing-service...${NC}"
    
    kubectl apply -f infrastructure/kubernetes/processing-service/processing-service.yaml
    kubectl rollout restart deployment/processing-service -n fiapx
    kubectl rollout status deployment/processing-service -n fiapx
    
    echo -e "${GREEN}✅ Processing-service atualizado${NC}"
}

# Função para testar métricas
test_metrics() {
    echo -e "${YELLOW}🧪 Testando endpoint de métricas...${NC}"
    
    # Port-forward temporário para testar
    kubectl port-forward svc/processing-service 8080:8080 -n fiapx &
    PF_PID=$!
    
    sleep 5
    
    if curl -s http://localhost:8080/metrics | grep -q "go_info"; then
        echo -e "${GREEN}✅ Métricas expostas corretamente${NC}"
    else
        echo -e "${RED}❌ Falha ao acessar métricas${NC}"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

# Função para gerar instruções de acesso
generate_access_instructions() {
    echo ""
    echo -e "${BLUE}📋 INSTRUÇÕES DE ACESSO${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo ""
    echo -e "${YELLOW}🎯 Para acessar o Grafana:${NC}"
    echo -e "1. Port-forward: ${BLUE}kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring${NC}"
    echo -e "2. Acesse: ${BLUE}http://localhost:3000${NC}"
    echo -e "3. Login: ${BLUE}admin / prom-operator${NC}"
    echo ""
    echo -e "${YELLOW}📊 Para acessar o Prometheus:${NC}"
    echo -e "1. Port-forward: ${BLUE}kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring${NC}"
    echo -e "2. Acesse: ${BLUE}http://localhost:9090${NC}"
    echo ""
    echo -e "${YELLOW}🎪 Para importar dashboards no Grafana:${NC}"
    echo -e "- Dashboard ID 315: Kubernetes Cluster Monitoring"
    echo -e "- Dashboard ID 6671: Go Processes"
    echo -e "- Dashboard customizado: /grafana-dashboards/fiapx-dashboard.json"
    echo ""
    echo -e "${YELLOW}🔍 Queries úteis no Prometheus:${NC}"
    echo -e "- CPU: ${BLUE}rate(container_cpu_usage_seconds_total[5m])${NC}"
    echo -e "- Memory: ${BLUE}container_memory_usage_bytes${NC}"
    echo -e "- HTTP Requests: ${BLUE}rate(http_requests_total[5m])${NC}"
    echo -e "- Go Goroutines: ${BLUE}go_goroutines${NC}"
}

# Função para validar deployment
validate_deployment() {
    echo -e "${YELLOW}✅ Validando deployment...${NC}"
    
    # Verificar ServiceMonitor
    if kubectl get servicemonitor processing-service -n monitoring &> /dev/null; then
        echo -e "${GREEN}✅ ServiceMonitor encontrado${NC}"
    else
        echo -e "${RED}❌ ServiceMonitor não encontrado${NC}"
    fi
    
    # Verificar Grafana
    if kubectl get pod -l app.kubernetes.io/name=grafana -n monitoring | grep -q Running; then
        echo -e "${GREEN}✅ Grafana rodando${NC}"
    else
        echo -e "${RED}❌ Grafana não está rodando${NC}"
    fi
    
    # Verificar Prometheus
    if kubectl get pod -l app.kubernetes.io/name=prometheus -n monitoring | grep -q Running; then
        echo -e "${GREEN}✅ Prometheus rodando${NC}"
    else
        echo -e "${RED}❌ Prometheus não está rodando${NC}"
    fi
    
    # Verificar processing-service
    if kubectl get pod -l app=processing-service -n fiapx | grep -q Running; then
        echo -e "${GREEN}✅ Processing-service rodando${NC}"
    else
        echo -e "${RED}❌ Processing-service não está rodando${NC}"
    fi
}

# Main execution
main() {
    validate_prerequisites
    echo ""
    
    apply_servicemonitor
    echo ""
    
    install_monitoring_stack
    echo ""
    
    wait_for_pods
    echo ""
    
    update_processing_service
    echo ""
    
    test_metrics
    echo ""
    
    validate_deployment
    echo ""
    
    generate_access_instructions
    
    echo ""
    echo -e "${GREEN}🎉 DEPLOY DE OBSERVABILIDADE CONCLUÍDO!${NC}"
    echo -e "${BLUE}Sistema pronto para monitoramento e evidências visuais.${NC}"
}

# Executar função principal
main "$@"
