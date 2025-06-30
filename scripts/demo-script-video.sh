#!/bin/bash

# ========================================
# SCRIPT DE DEMONSTRAÇÃO - PROJETO FIAP-X
# Para uso durante gravação do vídeo
# ========================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎬 FIAP-X - SCRIPT DE DEMONSTRAÇÃO PARA VÍDEO${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# Função para pausar e aguardar input
pause_for_video() {
    echo -e "${YELLOW}⏸️  Pressione ENTER para continuar com a próxima etapa...${NC}"
    read -r
}

# Função para mostrar comando antes de executar
show_and_run() {
    echo -e "${BLUE}💻 Executando:${NC} $1"
    echo -e "${YELLOW}$1${NC}"
    eval "$1"
    echo ""
}

# 1. VERIFICAÇÃO INICIAL DO AMBIENTE
echo -e "${GREEN}📋 ETAPA 1: VERIFICAÇÃO DO AMBIENTE${NC}"
echo "=================================="
pause_for_video

echo -e "${YELLOW}🔍 Conectando ao cluster AWS...${NC}"
show_and_run "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click 'kubectl cluster-info'"

echo -e "${YELLOW}🔍 Verificando pods do projeto...${NC}"
show_and_run "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click 'kubectl get pods -n fiapx'"

echo -e "${YELLOW}🔍 Verificando pods de monitoramento...${NC}"
show_and_run "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click 'kubectl get pods -n monitoring | grep -E \"grafana|prometheus\"'"

pause_for_video

# 2. SERVIÇOS E HPA
echo -e "${GREEN}📋 ETAPA 2: VALIDAÇÃO DOS SERVIÇOS${NC}"
echo "================================="
pause_for_video

echo -e "${YELLOW}🔍 Serviços expostos...${NC}"
show_and_run "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click 'kubectl get svc -n fiapx'"

echo -e "${YELLOW}🔍 Status do HPA...${NC}"
show_and_run "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click 'kubectl get hpa -n fiapx'"

pause_for_video

# 3. TESTE DE MÉTRICAS
echo -e "${GREEN}📋 ETAPA 3: VALIDAÇÃO DE MÉTRICAS${NC}"
echo "================================"
pause_for_video

echo -e "${YELLOW}🔍 Testando endpoint de métricas...${NC}"
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "
kubectl port-forward svc/processing-service 8080:8080 -n fiapx &
PF_PID=\$!
sleep 3
echo 'Métricas disponíveis:'
curl -s http://localhost:8080/metrics | grep -E '^(go_info|up|promhttp)' | head -5
kill \$PF_PID 2>/dev/null || true
"

pause_for_video

# 4. CONFIGURAÇÃO DOS PORT-FORWARDS
echo -e "${GREEN}📋 ETAPA 4: CONFIGURANDO ACESSOS${NC}"
echo "=============================="
pause_for_video

echo -e "${YELLOW}🌐 INSTRUÇÕES PARA PORT-FORWARD:${NC}"
echo ""
echo -e "${BLUE}Terminal 1 - Grafana:${NC}"
echo "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click"
echo "kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo ""
echo -e "${BLUE}Terminal 2 - Prometheus:${NC}"
echo "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click"
echo "kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo ""

# Obter senha do Grafana
echo -e "${YELLOW}🔑 Obtendo credenciais do Grafana...${NC}"
GRAFANA_PASSWORD=$(ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d")
echo -e "${GREEN}Grafana Login:${NC}"
echo -e "${BLUE}URL:${NC} http://localhost:3000"
echo -e "${BLUE}User:${NC} admin"
echo -e "${BLUE}Password:${NC} $GRAFANA_PASSWORD"
echo ""

pause_for_video

# 5. QUERIES ÚTEIS PARA DEMONSTRAÇÃO
echo -e "${GREEN}📋 ETAPA 5: QUERIES PARA PROMETHEUS${NC}"
echo "================================="
pause_for_video

echo -e "${YELLOW}📊 Queries recomendadas para o vídeo:${NC}"
echo ""
echo -e "${BLUE}1. Status do Processing Service:${NC}"
echo "up{job=\"processing-service\"}"
echo ""
echo -e "${BLUE}2. CPU Usage:${NC}"
echo "rate(container_cpu_usage_seconds_total{namespace=\"fiapx\"}[5m]) * 100"
echo ""
echo -e "${BLUE}3. Memory Usage:${NC}"
echo "container_memory_usage_bytes{namespace=\"fiapx\"} / 1024 / 1024"
echo ""
echo -e "${BLUE}4. Go Goroutines:${NC}"
echo "go_goroutines{job=\"processing-service\"}"
echo ""
echo -e "${BLUE}5. HTTP Requests:${NC}"
echo "rate(promhttp_metric_handler_requests_total[5m])"
echo ""

pause_for_video

# 6. TESTE DE CARGA PARA HPA
echo -e "${GREEN}📋 ETAPA 6: DEMONSTRAÇÃO DE AUTO-SCALING${NC}"
echo "======================================"
pause_for_video

echo -e "${YELLOW}🚀 Comandos para teste de carga:${NC}"
echo ""
echo -e "${BLUE}Terminal 1 - Monitor HPA:${NC}"
echo "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click"
echo "kubectl get hpa -n fiapx -w"
echo ""
echo -e "${BLUE}Terminal 2 - Gerar Carga:${NC}"
echo "ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click"
echo "kubectl run load-test --image=busybox --rm -it --restart=Never -- /bin/sh"
echo ""
echo -e "${BLUE}Dentro do pod de teste:${NC}"
echo "while true; do wget -q -O- http://processing-service.fiapx.svc.cluster.local:8080/health; done"
echo ""

pause_for_video

# 7. INFORMAÇÕES DO FRONTEND
echo -e "${GREEN}📋 ETAPA 7: ACESSO AO FRONTEND${NC}"
echo "============================"
pause_for_video

echo -e "${YELLOW}🌐 Frontend disponível em:${NC}"
echo -e "${BLUE}URL:${NC} https://api.wecando.click"
echo ""
echo -e "${YELLOW}👤 Usuário de teste sugerido:${NC}"
echo -e "${BLUE}Username:${NC} demo_user"
echo -e "${BLUE}Email:${NC} demo@fiapx.com"
echo -e "${BLUE}Password:${NC} Demo123!"
echo ""
echo -e "${YELLOW}👤 Usuário existente (se necessário):${NC}"
echo -e "${BLUE}Username:${NC} admin"
echo -e "${BLUE}Email:${NC} admin@fiapx.com"
echo -e "${BLUE}Password:${NC} admin123"
echo ""

pause_for_video

# 8. PIPELINE CI/CD
echo -e "${GREEN}📋 ETAPA 8: CI/CD PIPELINE${NC}"
echo "========================"
pause_for_video

echo -e "${YELLOW}🔄 GitHub Actions:${NC}"
echo "- Acesse o repositório no GitHub"
echo "- Vá para a aba 'Actions'"
echo "- Mostre workflows executados"
echo "- Destaque os quality gates e cobertura de testes"
echo ""

pause_for_video

# 9. DOCUMENTAÇÃO
echo -e "${GREEN}📋 ETAPA 9: DOCUMENTAÇÃO${NC}"
echo "======================="
pause_for_video

echo -e "${YELLOW}📚 Arquivos para mostrar no vídeo:${NC}"
echo "- DOCUMENTACAO-ARQUITETURA.md"
echo "- ROTEIRO-VIDEO-APRESENTACAO.md"
echo "- scripts/create_database.sql"
echo "- OBSERVABILITY-SUCCESS-REPORT.md"
echo "- observability-evidence-report-*.md"
echo ""

# 10. FINALIZAÇÃO
echo -e "${GREEN}📋 ETAPA 10: CHECKLIST FINAL${NC}"
echo "=========================="
pause_for_video

echo -e "${YELLOW}✅ Checklist para o vídeo:${NC}"
echo "□ Cluster AWS acessível"
echo "□ Todos os pods rodando"
echo "□ Port-forwards configurados"
echo "□ Grafana acessível (admin/$GRAFANA_PASSWORD)"
echo "□ Prometheus acessível"
echo "□ Frontend acessível (https://api.wecando.click)"
echo "□ HPA configurado e funcionando"
echo "□ Documentação preparada"
echo "□ Queries Prometheus testadas"
echo "□ Pipeline CI/CD visível no GitHub"
echo ""

echo -e "${GREEN}🎉 AMBIENTE PREPARADO PARA GRAVAÇÃO!${NC}"
echo ""
echo -e "${BLUE}📋 RESUMO DAS URLs:${NC}"
echo -e "${YELLOW}Frontend:${NC} https://api.wecando.click"
echo -e "${YELLOW}Grafana:${NC} http://localhost:3000 (admin/$GRAFANA_PASSWORD)"
echo -e "${YELLOW}Prometheus:${NC} http://localhost:9090"
echo ""
echo -e "${BLUE}⏱️  Tempo total de vídeo: 10 minutos máximo${NC}"
echo -e "${BLUE}🎯 Foco: Demonstração prática de funcionalidades${NC}"
echo ""
echo -e "${GREEN}🎬 BOA GRAVAÇÃO!${NC}"
