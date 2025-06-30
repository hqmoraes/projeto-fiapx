#!/bin/bash

# Script para Build e Deploy da Nova Imagem com Métricas
# Projeto FIAP-X - Sistema de Processamento de Vídeos

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 BUILD E DEPLOY - Processing Service com Métricas${NC}"
echo ""

# Variáveis
DOCKER_REGISTRY="hmoraes"
SERVICE_NAME="processing-service"
NEW_VERSION="v2.4-metrics"
NAMESPACE="fiapx"

# Função para build da imagem
build_image() {
    echo -e "${YELLOW}🔨 Building imagem Docker...${NC}"
    
    cd processing-service
    
    # Build da imagem
    docker build -t ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:${NEW_VERSION} .
    
    # Tag latest também
    docker tag ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:${NEW_VERSION} ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:latest
    
    echo -e "${GREEN}✅ Imagem built: ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:${NEW_VERSION}${NC}"
    cd ..
}

# Função para push da imagem
push_image() {
    echo -e "${YELLOW}📤 Pushing imagem para DockerHub...${NC}"
    
    docker push ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:${NEW_VERSION}
    docker push ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:latest
    
    echo -e "${GREEN}✅ Imagem enviada para registry${NC}"
}

# Função para atualizar YAML
update_yaml() {
    echo -e "${YELLOW}⚙️  Atualizando YAML do processing-service...${NC}"
    
    # Backup do arquivo original
    cp infrastructure/kubernetes/processing-service/processing-service.yaml infrastructure/kubernetes/processing-service/processing-service.yaml.backup
    
    # Atualizar a tag da imagem
    sed -i "s|image: ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:.*|image: ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:${NEW_VERSION}|g" infrastructure/kubernetes/processing-service/processing-service.yaml
    
    echo -e "${GREEN}✅ YAML atualizado com nova versão${NC}"
}

# Função para deploy no Kubernetes
deploy_to_k8s() {
    echo -e "${YELLOW}☸️  Fazendo deploy no Kubernetes...${NC}"
    
    # Aplicar o YAML atualizado
    kubectl apply -f infrastructure/kubernetes/processing-service/processing-service.yaml
    
    # Forçar rollout para pegar a nova imagem
    kubectl rollout restart deployment/${SERVICE_NAME} -n ${NAMESPACE}
    
    # Aguardar rollout completar
    kubectl rollout status deployment/${SERVICE_NAME} -n ${NAMESPACE}
    
    echo -e "${GREEN}✅ Deploy concluído${NC}"
}

# Função para validar deploy
validate_deploy() {
    echo -e "${YELLOW}✅ Validando deploy...${NC}"
    
    # Verificar pods
    kubectl get pods -l app=${SERVICE_NAME} -n ${NAMESPACE}
    
    # Testar endpoint de métricas
    echo -e "${BLUE}🧪 Testando endpoint /metrics...${NC}"
    
    # Port-forward temporário
    kubectl port-forward svc/${SERVICE_NAME} 8080:8080 -n ${NAMESPACE} &
    PF_PID=$!
    
    sleep 5
    
    if curl -s http://localhost:8080/metrics | grep -q "go_info"; then
        echo -e "${GREEN}✅ Endpoint /metrics funcionando${NC}"
    else
        echo -e "${RED}❌ Falha no endpoint /metrics${NC}"
    fi
    
    if curl -s http://localhost:8080/health | grep -q "healthy"; then
        echo -e "${GREEN}✅ Health check funcionando${NC}"
    else
        echo -e "${RED}❌ Falha no health check${NC}"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

# Função para gerar relatório
generate_report() {
    echo ""
    echo -e "${BLUE}📊 RELATÓRIO DE DEPLOY${NC}"
    echo -e "${GREEN}===================${NC}"
    echo -e "🎯 Serviço: ${SERVICE_NAME}"
    echo -e "🏷️  Nova versão: ${NEW_VERSION}"
    echo -e "🐳 Imagem: ${DOCKER_REGISTRY}/fiapx-${SERVICE_NAME}:${NEW_VERSION}"
    echo -e "📅 Data: $(date)"
    echo ""
    echo -e "${YELLOW}✅ Funcionalidades adicionadas:${NC}"
    echo -e "   📊 Endpoint /metrics Prometheus"
    echo -e "   🔍 Métricas Go detalhadas"
    echo -e "   📈 Compatibilidade com ServiceMonitor"
    echo -e "   ⚡ Ready para observabilidade"
    echo ""
    echo -e "${BLUE}📋 Próximos passos:${NC}"
    echo -e "1. Execute: ./scripts/deploy-observability-aws.sh"
    echo -e "2. Acesse Grafana e importe dashboards"
    echo -e "3. Colete evidências visuais"
    echo -e "4. Documente resultados"
}

# Main execution
main() {
    build_image
    echo ""
    
    push_image
    echo ""
    
    update_yaml
    echo ""
    
    deploy_to_k8s
    echo ""
    
    validate_deploy
    echo ""
    
    generate_report
    
    echo ""
    echo -e "${GREEN}🎉 BUILD E DEPLOY CONCLUÍDOS!${NC}"
    echo -e "${BLUE}Processing-service agora expõe métricas Prometheus.${NC}"
}

# Executar função principal
main "$@"
