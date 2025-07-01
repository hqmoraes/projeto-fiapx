#!/bin/bash

# Script para automatizar a geração de vídeos de demonstração do FIAP-X
# Uso: ./generate-demo-video.sh [DURATION_MINUTES] [--mode MODE] [--output OUTPUT_FILE]

set -e

# Configurações padrão
DEFAULT_DURATION=10
DEFAULT_MODE="full"
DEFAULT_OUTPUT="fiapx-demo-$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações de gravação
RESOLUTION="1920x1080"
FRAMERATE="30"
AUDIO_SAMPLE_RATE="44100"
VIDEO_CODEC="libx264"
AUDIO_CODEC="aac"

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_banner() {
    print_color $CYAN "
╔══════════════════════════════════════════════════════════════╗
║                    FIAP-X Video Generator                    ║
║              Automated Demo Video Creation                   ║
╚══════════════════════════════════════════════════════════════╝
"
}

show_help() {
    cat << EOF
Uso: $0 [DURATION] [OPTIONS]

PARÂMETROS:
    DURATION        Duração do vídeo em minutos (padrão: $DEFAULT_DURATION)

OPÇÕES:
    --mode MODE     Modo de gravação:
                    - full: Gravação completa (padrão)
                    - sections: Por seções separadas
                    - simulate: Apenas simula sem gravar
    --output FILE   Nome do arquivo de saída (sem extensão)
    --resolution    Resolução do vídeo (padrão: $RESOLUTION)
    --framerate     Taxa de frames (padrão: $FRAMERATE)
    --no-audio      Gerar vídeo sem áudio
    --help          Mostra esta ajuda

EXEMPLOS:
    $0 10                           # Vídeo de 10 minutos completo
    $0 15 --mode sections           # Vídeo por seções de 15 minutos
    $0 8 --output minha-demo        # Vídeo de 8 min com nome customizado
    $0 12 --no-audio --resolution 1280x720  # Vídeo sem áudio em 720p

SEÇÕES DISPONÍVEIS:
    1. Abertura (30s)
    2. Documentação e Arquitetura (2min)
    3. Ambiente e Infraestrutura (1min 30s)
    4. Demonstração - Criação de Usuário (1min)
    5. Upload e Processamento (2min)
    6. Observabilidade e Monitoramento (2min)
    7. CI/CD e Auto-scaling (1min 30s)
    8. Download dos Resultados (45s)
    9. Encerramento (30s)

DEPENDÊNCIAS NECESSÁRIAS:
    - ffmpeg
    - obs-studio (ou alternativa de screen recording)
    - xdotool (para automação de mouse/teclado)
    - curl
    - kubectl (configurado para cluster AWS)
    - ssh (configurado para acesso AWS)

EOF
}

check_dependencies() {
    print_color $BLUE "🔍 Verificando dependências..."
    
    local missing_deps=()
    
    # Verificar dependências essenciais
    local deps=("ffmpeg" "xdotool" "curl" "kubectl" "ssh")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_color $RED "❌ Dependências faltando:"
        printf '%s\n' "${missing_deps[@]}" | sed 's/^/  - /'
        echo ""
        print_color $YELLOW "💡 Para instalar no Ubuntu/Debian:"
        echo "sudo apt update && sudo apt install ffmpeg xdotool curl"
        echo ""
        print_color $YELLOW "💡 Para kubectl e acesso AWS:"
        echo "- Configure kubectl para o cluster AWS"
        echo "- Configure SSH com a chave do worker node"
        exit 1
    fi
    
    print_color $GREEN "✅ Todas as dependências estão instaladas"
}

validate_environment() {
    print_color $BLUE "🔍 Validando ambiente..."
    
    # Verificar se estamos no diretório correto
    if [ ! -f "$PROJECT_ROOT/ROTEIRO-VIDEO-APRESENTACAO.md" ]; then
        print_color $RED "❌ Execute este script a partir do diretório do projeto FIAP-X"
        exit 1
    fi
    
    # Verificar conectividade com cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_color $YELLOW "⚠️  kubectl não conectado ao cluster"
        print_color $YELLOW "💡 Configure kubectl antes de continuar"
    else
        print_color $GREEN "✅ kubectl conectado ao cluster"
    fi
    
    # Verificar SSH para AWS
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@worker.wecando.click "echo 'SSH OK'" 2>/dev/null; then
        print_color $YELLOW "⚠️  SSH para AWS não configurado"
        print_color $YELLOW "💡 Configure SSH antes de continuar"
    else
        print_color $GREEN "✅ SSH para AWS configurado"
    fi
    
    print_color $GREEN "✅ Ambiente validado"
}

calculate_section_timing() {
    local total_duration=$1
    local base_duration=630  # 10min 30s em segundos (duração base do roteiro)
    local scale_factor=$(echo "scale=2; $total_duration * 60 / $base_duration" | bc)
    
    # Tempos base de cada seção (em segundos)
    declare -A base_times=(
        ["abertura"]=30
        ["documentacao"]=120
        ["infraestrutura"]=90
        ["usuario"]=60
        ["upload"]=120
        ["observabilidade"]=120
        ["cicd"]=90
        ["download"]=45
        ["encerramento"]=30
    )
    
    # Calcular tempos ajustados
    declare -A section_times=()
    for section in "${!base_times[@]}"; do
        section_times[$section]=$(echo "scale=0; ${base_times[$section]} * $scale_factor" | bc)
    done
    
    # Retornar array global
    for section in "${!section_times[@]}"; do
        eval "SECTION_TIME_$section=${section_times[$section]}"
    done
}

setup_recording_environment() {
    print_color $BLUE "🎬 Configurando ambiente de gravação..."
    
    # Criar diretório de output
    mkdir -p "$PROJECT_ROOT/outputs/videos"
    
    # Configurar workspace para gravação
    cd "$PROJECT_ROOT"
    
    # Preparar terminais e browsers
    setup_terminals
    setup_browsers
    
    print_color $GREEN "✅ Ambiente de gravação configurado"
}

setup_terminals() {
    print_color $YELLOW "📟 Configurando terminais..."
    
    # Terminal principal (SSH AWS)
    gnome-terminal --title="AWS-SSH" --geometry=100x30+100+100 -- bash -c "
        echo 'Terminal AWS-SSH pronto'
        echo 'Comandos disponíveis:'
        echo '  ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click'
        echo '  kubectl get pods -A'
        echo '  kubectl get svc -n fiapx'
        echo '  kubectl get hpa -n fiapx'
        bash
    " &
    
    # Terminal para port-forwards
    gnome-terminal --title="Port-Forwards" --geometry=100x15+100+400 -- bash -c "
        echo 'Terminal Port-Forwards pronto'
        echo 'Comandos disponíveis:'
        echo '  kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring'
        echo '  kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring'
        bash
    " &
    
    # Terminal para monitoramento
    gnome-terminal --title="Monitoring" --geometry=100x15+100+700 -- bash -c "
        echo 'Terminal Monitoring pronto'
        echo 'Comandos disponíveis:'
        echo '  kubectl get hpa -n fiapx -w'
        echo '  watch kubectl get pods -n fiapx'
        bash
    " &
    
    sleep 2
}

setup_browsers() {
    print_color $YELLOW "🌐 Configurando browsers..."
    
    # Abrir browser principal para frontend
    google-chrome --new-window --app=https://fiapx.wecando.click 2>/dev/null &
    
    # Aguardar um pouco
    sleep 3
    
    # Preparar abas para Grafana e Prometheus (serão abertas durante gravação)
    print_color $GREEN "✅ Browsers configurados"
}

record_section() {
    local section_name=$1
    local duration=$2
    local commands=("${@:3}")
    
    print_color $CYAN "🎬 Gravando seção: $section_name (${duration}s)"
    
    local output_file="$PROJECT_ROOT/outputs/videos/${OUTPUT_PREFIX}_${section_name}.mp4"
    
    # Começar gravação de tela
    start_screen_recording "$output_file" "$duration"
    
    # Executar comandos da seção
    for cmd in "${commands[@]}"; do
        eval "$cmd"
        sleep 1
    done
    
    # Aguardar conclusão da gravação
    wait_for_recording_completion
    
    print_color $GREEN "✅ Seção $section_name gravada: $output_file"
}

start_screen_recording() {
    local output_file=$1
    local duration=$2
    
    # Usar ffmpeg para gravação de tela
    ffmpeg -f x11grab -s "$RESOLUTION" -r "$FRAMERATE" \
           -i :0.0 \
           -f pulse -ac 2 -ar "$AUDIO_SAMPLE_RATE" -i default \
           -c:v "$VIDEO_CODEC" -preset fast -crf 18 \
           -c:a "$AUDIO_CODEC" -b:a 128k \
           -t "$duration" \
           "$output_file" \
           >/dev/null 2>&1 &
    
    RECORDING_PID=$!
    echo "$RECORDING_PID" > /tmp/recording.pid
}

wait_for_recording_completion() {
    if [ -f /tmp/recording.pid ]; then
        local pid=$(cat /tmp/recording.pid)
        wait "$pid" 2>/dev/null || true
        rm -f /tmp/recording.pid
    fi
}

execute_section_abertura() {
    print_color $BLUE "📝 Executando: Abertura (${SECTION_TIME_abertura}s)"
    
    local commands=(
        "xdotool search --name 'ROTEIRO-VIDEO-APRESENTACAO.md' windowactivate"
        "sleep 2"
        "xdotool key ctrl+Home"
        "sleep 1"
        "speak 'Olá! Apresento o projeto FIAP-X, um sistema escalável de processamento de vídeos desenvolvido com arquitetura de microsserviços, rodando em produção na AWS com observabilidade completa.'"
    )
    
    record_section "abertura" "$SECTION_TIME_abertura" "${commands[@]}"
}

execute_section_documentacao() {
    print_color $BLUE "📝 Executando: Documentação e Arquitetura (${SECTION_TIME_documentacao}s)"
    
    local commands=(
        "xdotool search --name 'DOCUMENTACAO-ARQUITETURA.md' windowactivate"
        "sleep 2"
        "speak 'A arquitetura foi projetada com 5 microsserviços principais'"
        "sleep 5"
        "xdotool key Page_Down"
        "sleep 3"
        "speak 'Todos os requisitos foram implementados: processamento paralelo de múltiplos vídeos'"
        "sleep 10"
        "speak 'O projeto mantém alta qualidade com 84.6% de cobertura de testes'"
    )
    
    record_section "documentacao" "$SECTION_TIME_documentacao" "${commands[@]}"
}

execute_section_infraestrutura() {
    print_color $BLUE "📝 Executando: Ambiente e Infraestrutura (${SECTION_TIME_infraestrutura}s)"
    
    local commands=(
        "xdotool search --name 'AWS-SSH' windowactivate"
        "sleep 2"
        "xdotool type 'ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click'"
        "xdotool key Return"
        "sleep 5"
        "xdotool type 'kubectl get pods -A'"
        "xdotool key Return"
        "sleep 5"
        "speak 'O sistema roda em um cluster Kubernetes na AWS'"
        "sleep 3"
        "xdotool type 'kubectl get svc -n fiapx'"
        "xdotool key Return"
        "sleep 3"
        "xdotool type 'kubectl get hpa -n fiapx'"
        "xdotool key Return"
        "sleep 5"
        "speak 'Todos os serviços estão expostos e o HPA está ativo'"
    )
    
    record_section "infraestrutura" "$SECTION_TIME_infraestrutura" "${commands[@]}"
}

execute_section_usuario() {
    print_color $BLUE "📝 Executando: Demonstração - Criação de Usuário (${SECTION_TIME_usuario}s)"
    
    local commands=(
        "xdotool search --name 'Chrome' windowactivate"
        "sleep 2"
        "xdotool key F5"
        "sleep 5"
        "speak 'Vamos começar criando um usuário'"
        "sleep 3"
        "simulate_user_registration"
        "sleep 5"
        "speak 'Usuário criado com autenticação JWT'"
    )
    
    record_section "usuario" "$SECTION_TIME_usuario" "${commands[@]}"
}

execute_section_upload() {
    print_color $BLUE "📝 Executando: Upload e Processamento (${SECTION_TIME_upload}s)"
    
    local commands=(
        "simulate_video_upload"
        "sleep 10"
        "speak 'Upload Service valida os arquivos e cria jobs na fila'"
        "sleep 10"
        "simulate_processing_status"
        "sleep 15"
        "speak 'Múltiplos vídeos são processados em paralelo'"
    )
    
    record_section "upload" "$SECTION_TIME_upload" "${commands[@]}"
}

execute_section_observabilidade() {
    print_color $BLUE "📝 Executando: Observabilidade e Monitoramento (${SECTION_TIME_observabilidade}s)"
    
    local commands=(
        "open_prometheus_grafana"
        "sleep 10"
        "demonstrate_metrics"
        "sleep 20"
        "speak 'Prometheus coletando métricas dos serviços'"
        "sleep 10"
        "switch_to_grafana"
        "sleep 15"
        "speak 'Dashboards customizados para monitoramento de produção'"
    )
    
    record_section "observabilidade" "$SECTION_TIME_observabilidade" "${commands[@]}"
}

execute_section_cicd() {
    print_color $BLUE "📝 Executando: CI/CD e Auto-scaling (${SECTION_TIME_cicd}s)"
    
    local commands=(
        "open_github_actions"
        "sleep 10"
        "speak 'Pipeline CI/CD totalmente automatizado'"
        "sleep 10"
        "demonstrate_autoscaling"
        "sleep 15"
        "speak 'HPA escalando automaticamente baseado na carga'"
    )
    
    record_section "cicd" "$SECTION_TIME_cicd" "${commands[@]}"
}

execute_section_download() {
    print_color $BLUE "📝 Executando: Download dos Resultados (${SECTION_TIME_download}s)"
    
    local commands=(
        "xdotool search --name 'Chrome' windowactivate"
        "sleep 2"
        "simulate_download"
        "sleep 10"
        "speak 'Storage Service gera ZIP dinamicamente'"
        "sleep 5"
        "show_extracted_frames"
    )
    
    record_section "download" "$SECTION_TIME_download" "${commands[@]}"
}

execute_section_encerramento() {
    print_color $BLUE "📝 Executando: Encerramento (${SECTION_TIME_encerramento}s)"
    
    local commands=(
        "xdotool search --name 'ROTEIRO-VIDEO-APRESENTACAO.md' windowactivate"
        "sleep 2"
        "xdotool key ctrl+End"
        "sleep 2"
        "speak 'Sistema completo e escalável atendendo todos os requisitos'"
        "sleep 5"
        "speak 'Obrigado pela atenção! Este foi o projeto FIAP-X.'"
    )
    
    record_section "encerramento" "$SECTION_TIME_encerramento" "${commands[@]}"
}

# Funções auxiliares para simulação
simulate_user_registration() {
    # Simular cliques e digitação para registro de usuário
    xdotool mousemove 960 400
    xdotool click 1
    sleep 1
    xdotool type "demo_user"
    xdotool key Tab
    xdotool type "demo@fiapx.com"
    xdotool key Tab
    xdotool type "Demo123!"
    xdotool key Tab
    xdotool key Return
}

simulate_video_upload() {
    # Simular upload de vídeos
    xdotool mousemove 960 300
    xdotool click 1
    sleep 2
    xdotool key ctrl+o
    sleep 2
    xdotool key Return
}

simulate_processing_status() {
    # Simular visualização de status
    xdotool key F5
    sleep 3
    xdotool key F5
    sleep 3
    xdotool key F5
}

open_prometheus_grafana() {
    # Abrir Prometheus e Grafana
    google-chrome --new-tab http://localhost:9090 2>/dev/null &
    sleep 3
    google-chrome --new-tab http://localhost:3000 2>/dev/null &
    sleep 3
}

demonstrate_metrics() {
    # Demonstrar métricas no Prometheus
    xdotool search --name "Prometheus" windowactivate
    sleep 1
    xdotool type "up{job=\"processing-service\"}"
    xdotool key Return
}

switch_to_grafana() {
    # Trocar para Grafana
    xdotool search --name "Grafana" windowactivate
    sleep 2
}

open_github_actions() {
    # Abrir GitHub Actions
    google-chrome --new-tab https://github.com/hqmoraes/projeto-fiapx/actions 2>/dev/null &
    sleep 5
}

demonstrate_autoscaling() {
    # Demonstrar auto-scaling
    xdotool search --name "Monitoring" windowactivate
    sleep 1
    xdotool type "kubectl get hpa -n fiapx -w"
    xdotool key Return
}

simulate_download() {
    # Simular download de resultados
    xdotool mousemove 960 500
    xdotool click 1
    sleep 3
}

show_extracted_frames() {
    # Mostrar frames extraídos
    xdotool key alt+Tab
    sleep 2
}

speak() {
    local text="$1"
    if command -v espeak >/dev/null 2>&1; then
        echo "$text" | espeak -s 150 -v pt-br 2>/dev/null &
    else
        echo "🎤 NARRAÇÃO: $text"
    fi
}

combine_video_sections() {
    local output_final="$PROJECT_ROOT/outputs/videos/${OUTPUT_PREFIX}_final.mp4"
    
    print_color $BLUE "🎬 Combinando seções do vídeo..."
    
    # Criar lista de arquivos para concatenação
    local concat_list="$PROJECT_ROOT/outputs/videos/concat_list.txt"
    echo "# Lista de arquivos para concatenação" > "$concat_list"
    
    local sections=("abertura" "documentacao" "infraestrutura" "usuario" "upload" "observabilidade" "cicd" "download" "encerramento")
    
    for section in "${sections[@]}"; do
        local section_file="$PROJECT_ROOT/outputs/videos/${OUTPUT_PREFIX}_${section}.mp4"
        if [ -f "$section_file" ]; then
            echo "file '$(basename "$section_file")'" >> "$concat_list"
        fi
    done
    
    # Concatenar vídeos
    cd "$PROJECT_ROOT/outputs/videos"
    ffmpeg -f concat -safe 0 -i concat_list.txt -c copy "$output_final"
    
    print_color $GREEN "✅ Vídeo final criado: $output_final"
}

cleanup_temp_files() {
    print_color $BLUE "🧹 Limpando arquivos temporários..."
    
    # Remover arquivos de seção se modo não for 'sections'
    if [ "$MODE" != "sections" ]; then
        rm -f "$PROJECT_ROOT/outputs/videos/${OUTPUT_PREFIX}_"*.mp4
        rm -f "$PROJECT_ROOT/outputs/videos/concat_list.txt"
    fi
    
    # Limpar PIDs
    rm -f /tmp/recording.pid
    
    print_color $GREEN "✅ Limpeza concluída"
}

main() {
    print_banner
    
    # Parse argumentos
    DURATION=${1:-$DEFAULT_DURATION}
    MODE=$DEFAULT_MODE
    OUTPUT_PREFIX=$DEFAULT_OUTPUT
    NO_AUDIO=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                MODE="$2"
                shift 2
                ;;
            --output)
                OUTPUT_PREFIX="$2"
                shift 2
                ;;
            --resolution)
                RESOLUTION="$2"
                shift 2
                ;;
            --framerate)
                FRAMERATE="$2"
                shift 2
                ;;
            --no-audio)
                NO_AUDIO=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                if [[ $1 =~ ^[0-9]+$ ]]; then
                    DURATION=$1
                fi
                shift
                ;;
        esac
    done
    
    print_color $BLUE "⚙️  Configurações:"
    echo "  - Duração: ${DURATION} minutos"
    echo "  - Modo: $MODE"
    echo "  - Output: $OUTPUT_PREFIX"
    echo "  - Resolução: $RESOLUTION"
    echo "  - Framerate: $FRAMERATE"
    echo "  - Áudio: $([ "$NO_AUDIO" = true ] && echo "Desabilitado" || echo "Habilitado")"
    echo ""
    
    # Verificações
    check_dependencies
    validate_environment
    
    # Calcular tempos das seções
    calculate_section_timing "$DURATION"
    
    if [ "$MODE" = "simulate" ]; then
        print_color $YELLOW "🎭 Modo simulação - apenas mostrando o que seria executado"
        echo "Seções que seriam gravadas:"
        echo "  1. Abertura: ${SECTION_TIME_abertura}s"
        echo "  2. Documentação: ${SECTION_TIME_documentacao}s"
        echo "  3. Infraestrutura: ${SECTION_TIME_infraestrutura}s"
        echo "  4. Usuário: ${SECTION_TIME_usuario}s"
        echo "  5. Upload: ${SECTION_TIME_upload}s"
        echo "  6. Observabilidade: ${SECTION_TIME_observabilidade}s"
        echo "  7. CI/CD: ${SECTION_TIME_cicd}s"
        echo "  8. Download: ${SECTION_TIME_download}s"
        echo "  9. Encerramento: ${SECTION_TIME_encerramento}s"
        exit 0
    fi
    
    # Configurar ambiente
    setup_recording_environment
    
    print_color $CYAN "🎬 Iniciando gravação em 5 segundos..."
    sleep 5
    
    # Executar seções
    execute_section_abertura
    execute_section_documentacao
    execute_section_infraestrutura
    execute_section_usuario
    execute_section_upload
    execute_section_observabilidade
    execute_section_cicd
    execute_section_download
    execute_section_encerramento
    
    # Combinar vídeos se necessário
    if [ "$MODE" = "full" ]; then
        combine_video_sections
        cleanup_temp_files
    fi
    
    print_color $GREEN "🎉 Gravação concluída com sucesso!"
    print_color $BLUE "📁 Arquivos de output em: $PROJECT_ROOT/outputs/videos/"
    
    if [ "$MODE" = "sections" ]; then
        print_color $YELLOW "💡 Para combinar as seções manualmente:"
        echo "  cd $PROJECT_ROOT/outputs/videos"
        echo "  ./combine-sections.sh"
    fi
}

# Verificar se está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
