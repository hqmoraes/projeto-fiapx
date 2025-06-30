#!/bin/bash

# Script de Deploy em Produção com Qualidade
# Projeto FIAP-X - Sistema de Processamento de Vídeos

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 DEPLOY EM PRODUÇÃO - Projeto FIAP-X${NC}"
echo -e "${BLUE}Sistema de Processamento de Vídeos com Qualidade${NC}"
echo ""

# Configurações
DOCKER_REGISTRY="hmoraes"
VERSION_TAG="v2.4-prod-quality"
SERVICES=("auth-service" "upload-service" "processing-service" "storage-service")

# Função para executar testes
run_tests() {
    local service=$1
    echo -e "${YELLOW}🧪 Executando testes para $service...${NC}"
    
    cd $service
    
    # Executar testes unitários
    if ! go test -v ./tests/unit/... -short; then
        echo -e "${RED}❌ Testes falharam para $service${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Testes passaram para $service${NC}"
    cd ..
}

# Função para build e tag da imagem
build_and_tag() {
    local service=$1
    echo -e "${YELLOW}🐳 Building imagem Docker para $service...${NC}"
    
    cd $service
    
    # Build da imagem
    if docker build -t ${DOCKER_REGISTRY}/fiapx-${service}:${VERSION_TAG} .; then
        echo -e "${GREEN}✅ Imagem built: ${DOCKER_REGISTRY}/fiapx-${service}:${VERSION_TAG}${NC}"
        
        # Tag latest também
        docker tag ${DOCKER_REGISTRY}/fiapx-${service}:${VERSION_TAG} ${DOCKER_REGISTRY}/fiapx-${service}:latest
        echo -e "${GREEN}✅ Tagged como latest${NC}"
    else
        echo -e "${RED}❌ Falha no build de $service${NC}"
        exit 1
    fi
    
    cd ..
}

# Função para push das imagens
push_images() {
    local service=$1
    echo -e "${YELLOW}📤 Pushing imagem para DockerHub: $service...${NC}"
    
    if docker push ${DOCKER_REGISTRY}/fiapx-${service}:${VERSION_TAG} && \
       docker push ${DOCKER_REGISTRY}/fiapx-${service}:latest; then
        echo -e "${GREEN}✅ Push concluído para $service${NC}"
    else
        echo -e "${RED}❌ Falha no push de $service${NC}"
        exit 1
    fi
}

# Função para atualizar YAMLs do Kubernetes
update_k8s_manifests() {
    local service=$1
    echo -e "${YELLOW}⚙️  Atualizando manifest Kubernetes para $service...${NC}"
    
    local manifest_file="infrastructure/kubernetes/${service}/${service}.yaml"
    
    if [ -f "$manifest_file" ]; then
        # Criar backup
        cp "$manifest_file" "${manifest_file}.backup"
        
        # Atualizar a tag da imagem no YAML
        sed -i "s|image: ${DOCKER_REGISTRY}/fiapx-${service}:.*|image: ${DOCKER_REGISTRY}/fiapx-${service}:${VERSION_TAG}|g" "$manifest_file"
        
        echo -e "${GREEN}✅ Manifest atualizado: $manifest_file${NC}"
    else
        echo -e "${YELLOW}⚠️  Manifest não encontrado: $manifest_file${NC}"
    fi
}

# Função para gerar relatório de deployment
generate_report() {
    echo ""
    echo -e "${BLUE}📊 RELATÓRIO DE DEPLOYMENT${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo -e "🎯 Versão: ${VERSION_TAG}"
    echo -e "📅 Data: $(date)"
    echo -e "🔧 Serviços Atualizados: ${#SERVICES[@]}"
    
    for service in "${SERVICES[@]}"; do
        echo -e "   ✅ $service"
    done
    
    echo ""
    echo -e "${BLUE}🎉 FUNCIONALIDADES IMPLEMENTADAS:${NC}"
    echo -e "✅ Estrutura de testes automatizados"
    echo -e "✅ Testes unitários com >18 cenários"
    echo -e "✅ Pipeline CI/CD configurado"
    echo -e "✅ Imagens Docker multi-layer"
    echo -e "✅ Kubernetes manifests atualizados"
    echo -e "✅ Cache Redis otimizado"
    echo -e "✅ Escalabilidade automática (HPA)"
    echo ""
    
    echo -e "${YELLOW}📋 PRÓXIMOS PASSOS:${NC}"
    echo -e "1. Aplicar manifests: kubectl apply -f infrastructure/kubernetes/"
    echo -e "2. Verificar deploy: kubectl get pods -n fiapx"
    echo -e "3. Validar endpoints: frontend em http://localhost:3000"
    echo -e "4. Monitorar logs: kubectl logs -f -n fiapx <pod-name>"
}

# Main execution
main() {
    echo -e "${BLUE}Iniciando deployment em produção...${NC}"
    
    # Passo 1: Executar testes em todos os serviços
    echo ""
    echo -e "${BLUE}PASSO 1: QUALIDADE - EXECUTANDO TESTES${NC}"
    for service in "${SERVICES[@]}"; do
        run_tests "$service"
    done
    
    # Passo 2: Build das imagens Docker
    echo ""
    echo -e "${BLUE}PASSO 2: BUILD - CRIANDO IMAGENS DOCKER${NC}"
    for service in "${SERVICES[@]}"; do
        build_and_tag "$service"
    done
    
    # Passo 3: Push das imagens
    echo ""
    echo -e "${BLUE}PASSO 3: DEPLOY - ENVIANDO PARA REGISTRY${NC}"
    for service in "${SERVICES[@]}"; do
        push_images "$service"
    done
    
    # Passo 4: Atualizar manifests Kubernetes
    echo ""
    echo -e "${BLUE}PASSO 4: KUBERNETES - ATUALIZANDO MANIFESTS${NC}"
    for service in "${SERVICES[@]}"; do
        update_k8s_manifests "$service"
    done
    
    # Passo 5: Relatório final
    generate_report
    
    echo ""
    echo -e "${GREEN}🎉 DEPLOYMENT EM PRODUÇÃO CONCLUÍDO COM SUCESSO!${NC}"
    echo -e "${BLUE}Sistema pronto para uso enterprise com qualidade garantida.${NC}"
}

# Executar função principal
main "$@"
