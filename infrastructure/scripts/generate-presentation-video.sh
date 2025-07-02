#!/bin/bash

# =============================================================================
# Script para Geração Automatizada de Vídeo de Apresentação - FIAP-X
# =============================================================================
# Descrição: Automatiza a geração de vídeo de demonstração do sistema FIAP-X
# Uso: ./generate-presentation-video.sh <minutos_duracao>
# Exemplo: ./generate-presentation-video.sh 10
# =============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DURATION_MINUTES=${1:-10}
OUTPUT_DIR="$PROJECT_ROOT/outputs/presentation-video"
TEMP_DIR="$OUTPUT_DIR/temp"
FINAL_VIDEO="$OUTPUT_DIR/fiapx-presentation-$(date +%Y%m%d_%H%M%S).mp4"

# URLs e configurações
FRONTEND_URL="https://fiapx.wecando.click"
GRAFANA_URL="http://localhost:3000"
PROMETHEUS_URL="http://localhost:9090"
AWS_HOST="worker.wecando.click"
SSH_KEY="$HOME/.ssh/keyPrincipal.pem"

# Função para exibir ajuda
show_help() {
    echo -e "${BLUE}=== Gerador de Vídeo de Apresentação FIAP-X ===${NC}"
    echo ""
    echo "Uso: $0 <minutos_duracao> [opções]"
    echo ""
    echo "Parâmetros:"
    echo "  minutos_duracao    Duração do vídeo em minutos (padrão: 10)"
    echo ""
    echo "Opções:"
    echo "  -h, --help        Exibe esta ajuda"
    echo "  --simulate        Executa em modo simulação (sem gravação real)"
    echo "  --section <n>     Grava apenas a seção específica (1-7)"
    echo "  --no-setup        Pula verificações de setup"
    echo ""
    echo "Exemplos:"
    echo "  $0 10                          # Vídeo completo de 10 minutos"
    echo "  $0 5 --simulate               # Simulação de 5 minutos"
    echo "  $0 10 --section 3             # Apenas seção 3 (Demo usuário)"
    echo ""
    echo "Seções disponíveis:"
    echo "  1. Documentação e Arquitetura (2 min)"
    echo "  2. Ambiente e Infraestrutura (1.5 min)"
    echo "  3. Demonstração Prática - Usuário (1 min)"
    echo "  4. Upload e Processamento (2 min)"
    echo "  5. Observabilidade e Monitoramento (2 min)"
    echo "  6. CI/CD e Auto-scaling (1.5 min)"
    echo "  7. Download dos Resultados (45s)"
}

# Função para log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Função para validar dependências
check_dependencies() {
    log "Validando dependências..."
    
    local missing_deps=()
    
    # Verificar ferramentas de gravação
    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
    fi
    
    if ! command -v xwininfo &> /dev/null; then
        missing_deps+=("x11-utils (xwininfo)")
    fi
    
    if ! command -v xdotool &> /dev/null; then
        missing_deps+=("xdotool")
    fi
    
    if ! command -v scrot &> /dev/null && ! command -v gnome-screenshot &> /dev/null; then
        missing_deps+=("scrot ou gnome-screenshot")
    fi
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_deps+=("kubectl")
    fi
    
    # Verificar SSH key
    if [[ ! -f "$SSH_KEY" ]]; then
        missing_deps+=("Chave SSH: $SSH_KEY")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependências faltando:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Para instalar dependências, execute:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install ffmpeg x11-utils xdotool scrot"
        echo ""
        exit 1
    fi
    
    log "✅ Todas as dependências estão instaladas"
}

# Função para verificar conectividade
check_connectivity() {
    log "Verificando conectividade..."
    
    # Verificar acesso ao cluster AWS
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 ubuntu@"$AWS_HOST" "kubectl get nodes" &> /dev/null; then
        log_error "Não foi possível conectar ao cluster Kubernetes AWS"
        return 1
    fi
    
    # Verificar acesso ao frontend
    if ! curl -s --max-time 10 "$FRONTEND_URL" &> /dev/null; then
        log_warn "Frontend não está acessível: $FRONTEND_URL"
    fi
    
    log "✅ Conectividade validada"
}

# Função para setup do ambiente
setup_environment() {
    log "Configurando ambiente de gravação..."
    
    # Criar diretórios
    mkdir -p "$OUTPUT_DIR" "$TEMP_DIR"
    
    # Salvar configurações da sessão atual
    echo "DISPLAY=${DISPLAY:-:0}" > "$TEMP_DIR/session_config"
    echo "SCREEN_RESOLUTION=$(xdpyinfo | grep dimensions | awk '{print $2}')" >> "$TEMP_DIR/session_config"
    
    # Configurar port-forwards em background
    log "Configurando port-forwards..."
    
    # Killall previous port-forwards
    pkill -f "kubectl port-forward" || true
    sleep 2
    
    # Setup Grafana port-forward
    kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring > "$TEMP_DIR/grafana-pf.log" 2>&1 &
    echo $! > "$TEMP_DIR/grafana-pf.pid"
    
    # Setup Prometheus port-forward
    kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring > "$TEMP_DIR/prometheus-pf.log" 2>&1 &
    echo $! > "$TEMP_DIR/prometheus-pf.pid"
    
    # Aguardar port-forwards estarem prontos
    log "Aguardando port-forwards..."
    sleep 10
    
    # Verificar se port-forwards estão funcionando
    if ! curl -s http://localhost:3000 &> /dev/null; then
        log_warn "Grafana port-forward pode não estar funcionando"
    fi
    
    if ! curl -s http://localhost:9090 &> /dev/null; then
        log_warn "Prometheus port-forward pode não estar funcionando"
    fi
    
    log "✅ Ambiente configurado"
}

# Função para calcular timing das seções
calculate_section_timing() {
    local section=$1
    local total_duration=$DURATION_SECONDS
    
    # Duração das seções em segundos (baseado no roteiro)
    case $section in
        1) echo $((total_duration * 120 / 600))  ;; # 2 min de 10 min total
        2) echo $((total_duration * 90 / 600))   ;; # 1.5 min
        3) echo $((total_duration * 60 / 600))   ;; # 1 min
        4) echo $((total_duration * 120 / 600))  ;; # 2 min
        5) echo $((total_duration * 120 / 600))  ;; # 2 min
        6) echo $((total_duration * 90 / 600))   ;; # 1.5 min
        7) echo $((total_duration * 45 / 600))   ;; # 45s
        *) echo 60 ;;
    esac
}

# Função para gravar seção 1: Documentação e Arquitetura
record_section_1() {
    local duration=$(calculate_section_timing 1)
    log "📖 Gravando Seção 1: Documentação e Arquitetura (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Abrindo DOCUMENTACAO-ARQUITETURA.md"
        log "🎬 [SIMULAÇÃO] Navegando pela arquitetura de microsserviços"
        log "🎬 [SIMULAÇÃO] Destacando funcionalidades implementadas"
        log "🎬 [SIMULAÇÃO] Mostrando cobertura de testes 84.6%"
        sleep 5
        return
    fi
    
    # Abrir arquivo de documentação
    if [[ -f "$PROJECT_ROOT/DOCUMENTACAO-ARQUITETURA.md" ]]; then
        xdg-open "$PROJECT_ROOT/DOCUMENTACAO-ARQUITETURA.md" &
        sleep 3
    else
        log_warn "Arquivo DOCUMENTACAO-ARQUITETURA.md não encontrado"
    fi
    
    # Iniciar gravação da tela
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_1.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 1 gravada: $TEMP_DIR/section_1.mp4"
}

# Função para gravar seção 2: Ambiente e Infraestrutura
record_section_2() {
    local duration=$(calculate_section_timing 2)
    log "🏗️ Gravando Seção 2: Ambiente e Infraestrutura (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Conectando ao cluster AWS via SSH"
        log "🎬 [SIMULAÇÃO] Executando: kubectl get pods -A"
        log "🎬 [SIMULAÇÃO] Executando: kubectl get svc -n fiapx"
        log "🎬 [SIMULAÇÃO] Executando: kubectl get hpa -n fiapx"
        sleep 5
        return
    fi
    
    # Abrir terminal e conectar ao AWS
    gnome-terminal -- bash -c "
        ssh -i '$SSH_KEY' ubuntu@'$AWS_HOST' '
            echo \"=== Pods em execução ===\"
            kubectl get pods -A | grep -E \"fiapx|monitoring\"
            echo \"\"
            echo \"=== Serviços FIAP-X ===\"
            kubectl get svc -n fiapx
            echo \"\"
            echo \"=== Horizontal Pod Autoscaler ===\"
            kubectl get hpa -n fiapx
            echo \"\"
            echo \"Pressione ENTER para continuar...\"
            read
        '
    " &
    
    # Aguardar terminal abrir
    sleep 3
    
    # Iniciar gravação
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_2.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 2 gravada: $TEMP_DIR/section_2.mp4"
}

# Função para gravar seção 3: Demonstração Prática - Usuário
record_section_3() {
    local duration=$(calculate_section_timing 3)
    log "👤 Gravando Seção 3: Demonstração Prática - Usuário (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Abrindo frontend: $FRONTEND_URL"
        log "🎬 [SIMULAÇÃO] Navegando para página de cadastro"
        log "🎬 [SIMULAÇÃO] Preenchendo formulário: demo_user, demo@fiapx.com"
        log "🎬 [SIMULAÇÃO] Registrando usuário"
        sleep 5
        return
    fi
    
    # Abrir browser no frontend
    firefox "$FRONTEND_URL" &
    sleep 5
    
    # Iniciar gravação
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_3.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação (usuário deve interagir manualmente)
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 3 gravada: $TEMP_DIR/section_3.mp4"
}

# Função para gravar seção 4: Upload e Processamento
record_section_4() {
    local duration=$(calculate_section_timing 4)
    log "📤 Gravando Seção 4: Upload e Processamento (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Fazendo login no sistema"
        log "🎬 [SIMULAÇÃO] Navegando para seção de upload"
        log "🎬 [SIMULAÇÃO] Selecionando vídeos para upload"
        log "🎬 [SIMULAÇÃO] Acompanhando status em tempo real"
        sleep 5
        return
    fi
    
    # Iniciar gravação
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_4.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação (usuário deve interagir manualmente)
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 4 gravada: $TEMP_DIR/section_4.mp4"
}

# Função para gravar seção 5: Observabilidade
record_section_5() {
    local duration=$(calculate_section_timing 5)
    log "📊 Gravando Seção 5: Observabilidade e Monitoramento (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Abrindo Prometheus: $PROMETHEUS_URL"
        log "🎬 [SIMULAÇÃO] Executando query: up{job=\"processing-service\"}"
        log "🎬 [SIMULAÇÃO] Abrindo Grafana: $GRAFANA_URL"
        log "🎬 [SIMULAÇÃO] Mostrando dashboards customizados"
        sleep 5
        return
    fi
    
    # Abrir Prometheus
    firefox "$PROMETHEUS_URL" &
    sleep 3
    
    # Abrir Grafana em nova aba
    firefox "$GRAFANA_URL" &
    sleep 3
    
    # Iniciar gravação
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_5.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 5 gravada: $TEMP_DIR/section_5.mp4"
}

# Função para gravar seção 6: CI/CD e Auto-scaling
record_section_6() {
    local duration=$(calculate_section_timing 6)
    log "🔄 Gravando Seção 6: CI/CD e Auto-scaling (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Abrindo GitHub Actions workflows"
        log "🎬 [SIMULAÇÃO] Mostrando pipeline em execução"
        log "🎬 [SIMULAÇÃO] Simulando carga para HPA"
        log "🎬 [SIMULAÇÃO] Monitorando auto-scaling"
        sleep 5
        return
    fi
    
    # Abrir GitHub no browser
    firefox "https://github.com/hqmoraes/projeto-fiapx/actions" &
    sleep 3
    
    # Abrir terminal para HPA monitoring
    gnome-terminal -- bash -c "
        ssh -i '$SSH_KEY' ubuntu@'$AWS_HOST' '
            echo \"=== Monitorando HPA ===\"
            kubectl get hpa -n fiapx -w
        '
    " &
    
    sleep 3
    
    # Iniciar gravação
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_6.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 6 gravada: $TEMP_DIR/section_6.mp4"
}

# Função para gravar seção 7: Download dos Resultados
record_section_7() {
    local duration=$(calculate_section_timing 7)
    log "💾 Gravando Seção 7: Download dos Resultados (${duration}s)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎬 [SIMULAÇÃO] Voltando ao dashboard web"
        log "🎬 [SIMULAÇÃO] Mostrando jobs COMPLETED"
        log "🎬 [SIMULAÇÃO] Fazendo download do ZIP"
        log "🎬 [SIMULAÇÃO] Abrindo ZIP com frames extraídos"
        sleep 5
        return
    fi
    
    # Focar no browser com o frontend
    firefox "$FRONTEND_URL" &
    sleep 3
    
    # Iniciar gravação
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 -t $duration -y "$TEMP_DIR/section_7.mp4" &
    local ffmpeg_pid=$!
    
    # Aguardar gravação
    sleep $duration
    
    # Finalizar gravação
    kill $ffmpeg_pid 2>/dev/null || true
    wait $ffmpeg_pid 2>/dev/null || true
    
    log "✅ Seção 7 gravada: $TEMP_DIR/section_7.mp4"
}

# Função para combinar vídeos
combine_videos() {
    log "🎬 Combinando vídeos das seções..."
    
    # Criar lista de vídeos para concatenar
    local concat_file="$TEMP_DIR/concat_list.txt"
    echo "# Lista de vídeos para concatenar" > "$concat_file"
    
    local sections_to_combine=()
    
    if [[ -n "$SPECIFIC_SECTION" ]]; then
        sections_to_combine=("$SPECIFIC_SECTION")
    else
        sections_to_combine=(1 2 3 4 5 6 7)
    fi
    
    for section in "${sections_to_combine[@]}"; do
        if [[ -f "$TEMP_DIR/section_$section.mp4" ]]; then
            echo "file '$TEMP_DIR/section_$section.mp4'" >> "$concat_file"
        fi
    done
    
    # Combinar vídeos
    if [[ -s "$concat_file" ]]; then
        ffmpeg -f concat -safe 0 -i "$concat_file" -c copy "$FINAL_VIDEO" -y
        log "✅ Vídeo final criado: $FINAL_VIDEO"
    else
        log_error "Nenhum vídeo de seção encontrado para combinar"
        return 1
    fi
}

# Função para adicionar intro/outro
add_intro_outro() {
    log "🎬 Adicionando intro e outro..."
    
    # Criar intro simples com texto
    ffmpeg -f lavfi -i color=c=blue:s=1920x1080:d=3 \
           -vf "drawtext=text='FIAP-X - Sistema de Processamento de Vídeos':fontcolor=white:fontsize=60:x=(w-text_w)/2:y=(h-text_h)/2" \
           -y "$TEMP_DIR/intro.mp4"
    
    # Criar outro simples
    ffmpeg -f lavfi -i color=c=blue:s=1920x1080:d=2 \
           -vf "drawtext=text='Obrigado pela atenção!':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2" \
           -y "$TEMP_DIR/outro.mp4"
    
    # Combinar intro + conteúdo + outro
    local final_with_intro_outro="$OUTPUT_DIR/fiapx-presentation-complete-$(date +%Y%m%d_%H%M%S).mp4"
    
    echo "file '$TEMP_DIR/intro.mp4'" > "$TEMP_DIR/complete_concat.txt"
    echo "file '$FINAL_VIDEO'" >> "$TEMP_DIR/complete_concat.txt"
    echo "file '$TEMP_DIR/outro.mp4'" >> "$TEMP_DIR/complete_concat.txt"
    
    ffmpeg -f concat -safe 0 -i "$TEMP_DIR/complete_concat.txt" -c copy "$final_with_intro_outro" -y
    
    log "✅ Vídeo completo criado: $final_with_intro_outro"
    FINAL_VIDEO="$final_with_intro_outro"
}

# Função para cleanup
cleanup() {
    log "🧹 Limpando arquivos temporários..."
    
    # Matar port-forwards
    if [[ -f "$TEMP_DIR/grafana-pf.pid" ]]; then
        kill $(cat "$TEMP_DIR/grafana-pf.pid") 2>/dev/null || true
    fi
    
    if [[ -f "$TEMP_DIR/prometheus-pf.pid" ]]; then
        kill $(cat "$TEMP_DIR/prometheus-pf.pid") 2>/dev/null || true
    fi
    
    # Remover arquivos temporários se solicitado
    if [[ "$KEEP_TEMP" != "true" ]]; then
        rm -rf "$TEMP_DIR"
        log "✅ Arquivos temporários removidos"
    else
        log "📁 Arquivos temporários mantidos em: $TEMP_DIR"
    fi
}

# Função principal
main() {
    log "🎬 Iniciando geração de vídeo de apresentação FIAP-X"
    log "⏱️ Duração: $DURATION_MINUTES minutos ($DURATION_SECONDS segundos)"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log "🎯 Modo simulação ativado"
    fi
    
    if [[ -n "$SPECIFIC_SECTION" ]]; then
        log "📋 Gravando apenas seção: $SPECIFIC_SECTION"
    fi
    
    # Setup
    if [[ "$NO_SETUP" != "true" ]]; then
        check_dependencies
        check_connectivity
    fi
    
    setup_environment
    
    # Gravar seções
    if [[ -n "$SPECIFIC_SECTION" ]]; then
        case $SPECIFIC_SECTION in
            1) record_section_1 ;;
            2) record_section_2 ;;
            3) record_section_3 ;;
            4) record_section_4 ;;
            5) record_section_5 ;;
            6) record_section_6 ;;
            7) record_section_7 ;;
            *) log_error "Seção inválida: $SPECIFIC_SECTION"; exit 1 ;;
        esac
    else
        record_section_1
        record_section_2
        record_section_3
        record_section_4
        record_section_5
        record_section_6
        record_section_7
    fi
    
    # Pós-processamento
    if [[ "$SIMULATE" != "true" ]]; then
        combine_videos
        add_intro_outro
    fi
    
    cleanup
    
    log "🎉 Geração de vídeo concluída!"
    log "📁 Arquivo final: $FINAL_VIDEO"
    log "⏱️ Duração total: $DURATION_MINUTES minutos"
}

# Tratamento de sinais
trap cleanup EXIT

# Parse de argumentos
SIMULATE=false
SPECIFIC_SECTION=""
NO_SETUP=false
KEEP_TEMP=false
DURATION_MINUTES=10
DURATION_SECONDS=600

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --simulate)
            SIMULATE=true
            shift
            ;;
        --section)
            SPECIFIC_SECTION="$2"
            shift 2
            ;;
        --no-setup)
            NO_SETUP=true
            shift
            ;;
        --keep-temp)
            KEEP_TEMP=true
            shift
            ;;
        -*)
            log_error "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "${1:-}" ]] || [[ "$1" =~ ^- ]]; then
                break
            elif [[ "$1" =~ ^[0-9]+$ ]]; then
                DURATION_MINUTES="$1"
                DURATION_SECONDS=$((DURATION_MINUTES * 60))
            else
                log_error "Parâmetro inválido: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validar parâmetros
if [[ ! "$DURATION_MINUTES" =~ ^[0-9]+$ ]] || [[ "$DURATION_MINUTES" -lt 1 ]] || [[ "$DURATION_MINUTES" -gt 60 ]]; then
    log_error "Duração deve ser um número entre 1 e 60 minutos"
    exit 1
fi

# Executar função principal
main "$@"
