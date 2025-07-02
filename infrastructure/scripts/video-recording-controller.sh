#!/bin/bash

# =============================================================================
# Controlador Interativo de Gravação - FIAP-X
# =============================================================================
# Descrição: Interface interativa para controlar a gravação de vídeo
# Uso: ./video-recording-controller.sh
# =============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/outputs/presentation-video"

# Estado da gravação
RECORDING_PID=""
CURRENT_SECTION=""
START_TIME=""
SECTION_DURATION=""

# Função para exibir header
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           🎬 CONTROLADOR DE GRAVAÇÃO FIAP-X 🎬                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Função para exibir status atual
show_status() {
    echo -e "${CYAN}📊 STATUS ATUAL:${NC}"
    if [[ -n "$RECORDING_PID" ]]; then
        local elapsed=$(($(date +%s) - START_TIME))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        echo -e "  🔴 GRAVANDO - Seção $CURRENT_SECTION"
        echo -e "  ⏱️  Tempo: ${minutes}m${seconds}s / ${SECTION_DURATION}s"
        echo -e "  📁 PID: $RECORDING_PID"
    else
        echo -e "  ⚪ PARADO"
    fi
    echo ""
}

# Função para exibir menu principal
show_main_menu() {
    echo -e "${GREEN}🎯 OPÇÕES DISPONÍVEIS:${NC}"
    echo ""
    echo "  📋 SEÇÕES:"
    echo "    1) Documentação e Arquitetura (2 min)"
    echo "    2) Ambiente e Infraestrutura (1.5 min)"
    echo "    3) Demonstração Usuário (1 min)"
    echo "    4) Upload e Processamento (2 min)"
    echo "    5) Observabilidade (2 min)"
    echo "    6) CI/CD e Auto-scaling (1.5 min)"
    echo "    7) Download dos Resultados (45s)"
    echo ""
    echo "  🎬 CONTROLES:"
    echo "    f) Gravação COMPLETA (10 min)"
    echo "    r) Ver ROTEIRO da seção atual"
    echo "    s) PARAR gravação atual"
    echo "    p) PAUSAR/RETOMAR gravação"
    echo "    t) TESTAR modo simulação"
    echo ""
    echo "  🛠️ UTILITÁRIOS:"
    echo "    c) Verificar CONECTIVIDADE"
    echo "    m) Configurar MONITORAMENTO"
    echo "    l) Ver LOGS de gravação"
    echo "    o) Abrir pasta de OUTPUT"
    echo ""
    echo "    h) AJUDA detalhada"
    echo "    q) SAIR"
    echo ""
}

# Função para calcular duração da seção
get_section_duration() {
    case $1 in
        1) echo 120 ;;  # 2 min
        2) echo 90 ;;   # 1.5 min
        3) echo 60 ;;   # 1 min
        4) echo 120 ;;  # 2 min
        5) echo 120 ;;  # 2 min
        6) echo 90 ;;   # 1.5 min
        7) echo 45 ;;   # 45s
        f) echo 600 ;;  # 10 min completo
        *) echo 60 ;;
    esac
}

# Função para obter nome da seção
get_section_name() {
    case $1 in
        1) echo "Documentação e Arquitetura" ;;
        2) echo "Ambiente e Infraestrutura" ;;
        3) echo "Demonstração Usuário" ;;
        4) echo "Upload e Processamento" ;;
        5) echo "Observabilidade" ;;
        6) echo "CI/CD e Auto-scaling" ;;
        7) echo "Download dos Resultados" ;;
        f) echo "Gravação Completa" ;;
        *) echo "Seção Desconhecida" ;;
    esac
}

# Função para iniciar gravação
start_recording() {
    local section=$1
    local duration=$(get_section_duration $section)
    local section_name=$(get_section_name $section)
    
    if [[ -n "$RECORDING_PID" ]]; then
        echo -e "${RED}❌ Já existe uma gravação em andamento!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎬 Iniciando gravação: $section_name${NC}"
    echo -e "${YELLOW}⏱️  Duração: ${duration}s${NC}"
    echo ""
    echo "Prepare-se... A gravação começará em:"
    for i in 5 4 3 2 1; do
        echo -e "${RED}$i${NC}"
        sleep 1
    done
    echo -e "${GREEN}🔴 GRAVANDO!${NC}"
    
    if [[ "$section" == "f" ]]; then
        # Gravação completa
        "$SCRIPT_DIR/generate-presentation-video.sh" 10 &
    else
        # Gravação de seção específica
        "$SCRIPT_DIR/generate-presentation-video.sh" $((duration / 60 + 1)) --section $section &
    fi
    
    RECORDING_PID=$!
    CURRENT_SECTION=$section
    START_TIME=$(date +%s)
    SECTION_DURATION=$duration
    
    echo "Gravação iniciada com PID: $RECORDING_PID"
}

# Função para parar gravação
stop_recording() {
    if [[ -z "$RECORDING_PID" ]]; then
        echo -e "${YELLOW}⚠️  Nenhuma gravação em andamento${NC}"
        return 1
    fi
    
    echo -e "${RED}⏹️  Parando gravação...${NC}"
    kill $RECORDING_PID 2>/dev/null || true
    wait $RECORDING_PID 2>/dev/null || true
    
    RECORDING_PID=""
    CURRENT_SECTION=""
    START_TIME=""
    SECTION_DURATION=""
    
    echo -e "${GREEN}✅ Gravação parada${NC}"
}

# Função para mostrar roteiro da seção
show_section_script() {
    local section=${1:-$CURRENT_SECTION}
    
    if [[ -z "$section" ]]; then
        echo -e "${RED}❌ Nenhuma seção especificada${NC}"
        return 1
    fi
    
    echo -e "${PURPLE}📋 ROTEIRO - $(get_section_name $section):${NC}"
    echo ""
    
    case $section in
        1)
            echo "🎯 Foco: Arquitetura e documentação técnica"
            echo "📖 Abrir: DOCUMENTACAO-ARQUITETURA.md"
            echo "🔍 Destacar: Microsserviços, padrões, cobertura de testes"
            echo "⏱️  Duração: 2 minutos"
            ;;
        2)
            echo "🎯 Foco: Infraestrutura Kubernetes"
            echo "🖥️  Conectar: SSH ao cluster AWS"
            echo "⚙️  Comandos: kubectl get pods, svc, hpa"
            echo "⏱️  Duração: 1.5 minutos"
            ;;
        3)
            echo "🎯 Foco: Interface do usuário"
            echo "🌐 Abrir: https://fiapx.wecando.click"
            echo "👤 Ação: Cadastro e login"
            echo "⏱️  Duração: 1 minuto"
            ;;
        4)
            echo "🎯 Foco: Upload e processamento"
            echo "📤 Ação: Upload múltiplos vídeos"
            echo "📊 Mostrar: Status em tempo real"
            echo "⏱️  Duração: 2 minutos"
            ;;
        5)
            echo "🎯 Foco: Monitoramento"
            echo "📊 Abrir: Prometheus + Grafana"
            echo "📈 Mostrar: Métricas e dashboards"
            echo "⏱️  Duração: 2 minutos"
            ;;
        6)
            echo "🎯 Foco: CI/CD e escalabilidade"
            echo "🔄 Mostrar: GitHub Actions"
            echo "📈 Simular: Auto-scaling"
            echo "⏱️  Duração: 1.5 minutos"
            ;;
        7)
            echo "🎯 Foco: Resultados finais"
            echo "💾 Ação: Download ZIP"
            echo "✅ Validar: Qualidade dos vídeos"
            echo "⏱️  Duração: 45 segundos"
            ;;
    esac
    echo ""
}

# Função para verificar conectividade
check_connectivity() {
    echo -e "${CYAN}🔍 Verificando conectividade...${NC}"
    echo ""
    
    # Frontend
    echo -n "Frontend (fiapx.wecando.click): "
    if curl -s --max-time 10 https://fiapx.wecando.click > /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FALHA${NC}"
    fi
    
    # AWS Cluster
    echo -n "Cluster AWS: "
    if ssh -i ~/.ssh/keyPrincipal.pem -o ConnectTimeout=10 ubuntu@worker.wecando.click "kubectl get nodes" &> /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FALHA${NC}"
    fi
    
    # Port-forwards
    echo -n "Grafana (localhost:3000): "
    if curl -s --max-time 5 http://localhost:3000 > /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Port-forward necessário${NC}"
    fi
    
    echo -n "Prometheus (localhost:9090): "
    if curl -s --max-time 5 http://localhost:9090 > /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Port-forward necessário${NC}"
    fi
    
    echo ""
}

# Função para configurar monitoramento
setup_monitoring() {
    echo -e "${CYAN}📊 Configurando port-forwards...${NC}"
    
    # Killall existing port-forwards
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    # Setup Grafana
    echo "Configurando Grafana..."
    kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring &
    
    # Setup Prometheus
    echo "Configurando Prometheus..."
    kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &
    
    echo ""
    echo -e "${GREEN}✅ Port-forwards configurados${NC}"
    echo "  - Grafana: http://localhost:3000"
    echo "  - Prometheus: http://localhost:9090"
    echo ""
}

# Função para mostrar logs
show_logs() {
    echo -e "${CYAN}📋 Logs de gravação:${NC}"
    echo ""
    
    if [[ -d "$OUTPUT_DIR/temp" ]]; then
        ls -la "$OUTPUT_DIR/temp/"*.log 2>/dev/null || echo "Nenhum log encontrado"
    else
        echo "Diretório de logs não encontrado"
    fi
    
    echo ""
}

# Função para abrir pasta de output
open_output_folder() {
    if [[ -d "$OUTPUT_DIR" ]]; then
        echo -e "${GREEN}📁 Abrindo pasta de output...${NC}"
        xdg-open "$OUTPUT_DIR" 2>/dev/null || \
        gnome-open "$OUTPUT_DIR" 2>/dev/null || \
        echo "Pasta: $OUTPUT_DIR"
    else
        echo -e "${RED}❌ Pasta de output não encontrada${NC}"
    fi
}

# Função para mostrar ajuda
show_help() {
    echo -e "${BLUE}📖 AJUDA DETALHADA:${NC}"
    echo ""
    echo "🎬 GRAVAÇÃO:"
    echo "  - Escolha uma seção (1-7) ou gravação completa (f)"
    echo "  - A gravação iniciará após contagem de 5 segundos"
    echo "  - Durante a gravação, siga o roteiro da seção"
    echo "  - Use 's' para parar a gravação a qualquer momento"
    echo ""
    echo "📋 SEÇÕES:"
    echo "  1. Documentação - Mostrar arquitetura e documentação"
    echo "  2. Infraestrutura - Demonstrar cluster Kubernetes"
    echo "  3. Demo Usuário - Cadastro e interface web"
    echo "  4. Upload - Processamento de vídeos"
    echo "  5. Observabilidade - Métricas e monitoramento"
    echo "  6. CI/CD - Pipeline e auto-scaling"
    echo "  7. Download - Resultados finais"
    echo ""
    echo "🛠️ PREPARAÇÃO:"
    echo "  - Execute 'c' para verificar conectividade"
    echo "  - Execute 'm' para configurar port-forwards"
    echo "  - Execute 't' para testar em modo simulação"
    echo ""
    echo "📁 ARQUIVOS:"
    echo "  - Vídeos salvos em: $OUTPUT_DIR"
    echo "  - Logs em: $OUTPUT_DIR/temp/"
    echo ""
}

# Função para processar entrada do usuário
process_input() {
    local choice=$1
    
    case $choice in
        [1-7])
            start_recording $choice
            ;;
        f|F)
            start_recording f
            ;;
        r|R)
            show_section_script
            ;;
        s|S)
            stop_recording
            ;;
        p|P)
            echo -e "${YELLOW}⚠️  Funcionalidade de pausa não implementada${NC}"
            ;;
        t|T)
            echo -e "${CYAN}🧪 Executando teste em modo simulação...${NC}"
            "$SCRIPT_DIR/generate-presentation-video.sh" 1 --simulate
            ;;
        c|C)
            check_connectivity
            ;;
        m|M)
            setup_monitoring
            ;;
        l|L)
            show_logs
            ;;
        o|O)
            open_output_folder
            ;;
        h|H)
            show_help
            ;;
        q|Q)
            if [[ -n "$RECORDING_PID" ]]; then
                echo -e "${YELLOW}⚠️  Parando gravação antes de sair...${NC}"
                stop_recording
            fi
            echo -e "${GREEN}👋 Até logo!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida: $choice${NC}"
            ;;
    esac
}

# Loop principal
main_loop() {
    while true; do
        show_header
        show_status
        show_main_menu
        
        echo -n -e "${CYAN}Digite sua opção: ${NC}"
        read -r choice
        
        echo ""
        process_input "$choice"
        
        echo ""
        echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
        read -r
    done
}

# Verificar dependências básicas
check_basic_deps() {
    local missing=()
    
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    if ! command -v ffmpeg &> /dev/null; then
        missing+=("ffmpeg")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Dependências faltando: ${missing[*]}${NC}"
        echo ""
        echo "Execute primeiro:"
        echo "  ./setup-video-recording.sh"
        echo ""
        exit 1
    fi
}

# Função principal
main() {
    # Verificar dependências
    check_basic_deps
    
    # Criar diretórios necessários
    mkdir -p "$OUTPUT_DIR"
    
    # Iniciar loop principal
    main_loop
}

# Executar
main "$@"
