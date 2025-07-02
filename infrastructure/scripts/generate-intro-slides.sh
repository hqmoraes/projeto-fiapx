#!/bin/bash

# =============================================================================
# Script para Geração de Slides Introdutórios - FIAP-X
# =============================================================================
# Descrição: Cria slides introdutórios para o vídeo de apresentação
# Uso: ./generate-intro-slides.sh
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
OUTPUT_DIR="$PROJECT_ROOT/outputs/presentation-video"
SLIDES_DIR="$OUTPUT_DIR/slides"

# Função para log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Função para criar slide
create_slide() {
    local slide_number=$1
    local title="$2"
    local content="$3"
    local duration=${4:-3}
    local background_color=${5:-"#1e3a8a"}
    local text_color=${6:-"white"}
    
    local output_file="$SLIDES_DIR/slide_${slide_number}.mp4"
    
    log "Criando slide $slide_number: $title"
    
    # Criar slide com FFmpeg
    ffmpeg -f lavfi -i "color=c=$background_color:s=1920x1080:d=$duration" \
           -vf "drawtext=text='$title':fontcolor=$text_color:fontsize=72:x=(w-text_w)/2:y=150:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='$content':fontcolor=$text_color:fontsize=36:x=(w-text_w)/2:y=400:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" \
           -y "$output_file" 2>/dev/null
    
    echo "$output_file"
}

# Função para criar slide com múltiplas linhas
create_multiline_slide() {
    local slide_number=$1
    local title="$2"
    local line1="$3"
    local line2="$4"
    local line3="$5"
    local line4="$6"
    local duration=${7:-4}
    local background_color=${8:-"#1e3a8a"}
    
    local output_file="$SLIDES_DIR/slide_${slide_number}.mp4"
    
    log "Criando slide multi-linha $slide_number: $title"
    
    ffmpeg -f lavfi -i "color=c=$background_color:s=1920x1080:d=$duration" \
           -vf "drawtext=text='$title':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=120:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='$line1':fontcolor=white:fontsize=42:x=(w-text_w)/2:y=300:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf,
                drawtext=text='$line2':fontcolor=white:fontsize=42:x=(w-text_w)/2:y=380:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf,
                drawtext=text='$line3':fontcolor=white:fontsize=42:x=(w-text_w)/2:y=460:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf,
                drawtext=text='$line4':fontcolor=white:fontsize=42:x=(w-text_w)/2:y=540:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" \
           -y "$output_file" 2>/dev/null
    
    echo "$output_file"
}

# Função para criar slide de arquitetura
create_architecture_slide() {
    local slide_number=$1
    local duration=${2:-5}
    
    local output_file="$SLIDES_DIR/slide_${slide_number}.mp4"
    
    log "Criando slide de arquitetura $slide_number"
    
    # Criar slide com diagrama de arquitetura em texto
    ffmpeg -f lavfi -i "color=c=#0f172a:s=1920x1080:d=$duration" \
           -vf "drawtext=text='ARQUITETURA DO SISTEMA':fontcolor=white:fontsize=56:x=(w-text_w)/2:y=80:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='┌─────────────┐    ┌─────────────┐    ┌─────────────┐':fontcolor=#60a5fa:fontsize=24:x=(w-text_w)/2:y=200:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='│   Frontend  │───▶│ API Gateway │───▶│ Processing  │':fontcolor=#60a5fa:fontsize=24:x=(w-text_w)/2:y=240:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='│   React     │    │   Port 8080 │    │   Service   │':fontcolor=#60a5fa:fontsize=24:x=(w-text_w)/2:y=280:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='└─────────────┘    └─────────────┘    └─────────────┘':fontcolor=#60a5fa:fontsize=24:x=(w-text_w)/2:y=320:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='                                               │':fontcolor=#60a5fa:fontsize=24:x=(w-text_w)/2:y=360:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='┌─────────────┐    ┌─────────────┐    ┌─────────────┐':fontcolor=#34d399:fontsize=24:x=(w-text_w)/2:y=420:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='│ Notification│◀───│ PostgreSQL  │◀───│    Redis    │':fontcolor=#34d399:fontsize=24:x=(w-text_w)/2:y=460:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='│   Service   │    │  Database   │    │    Cache    │':fontcolor=#34d399:fontsize=24:x=(w-text_w)/2:y=500:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='└─────────────┘    └─────────────┘    └─────────────┘':fontcolor=#34d399:fontsize=24:x=(w-text_w)/2:y=540:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf,
                drawtext=text='Kubernetes • AWS • Auto-scaling • Observabilidade':fontcolor=#fbbf24:fontsize=32:x=(w-text_w)/2:y=640:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" \
           -y "$output_file" 2>/dev/null
    
    echo "$output_file"
}

# Função para criar slide de métricas
create_metrics_slide() {
    local slide_number=$1
    local duration=${2:-4}
    
    local output_file="$SLIDES_DIR/slide_${slide_number}.mp4"
    
    log "Criando slide de métricas $slide_number"
    
    ffmpeg -f lavfi -i "color=c=#065f46:s=1920x1080:d=$duration" \
           -vf "drawtext=text='MÉTRICAS DE QUALIDADE':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=120:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='✅ Cobertura de Testes: 84.6%':fontcolor=#10b981:fontsize=48:x=(w-text_w)/2:y=280:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='✅ Segurança: Auditoria Completa':fontcolor=#10b981:fontsize=48:x=(w-text_w)/2:y=360:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='✅ Performance: Sub-segundo':fontcolor=#10b981:fontsize=48:x=(w-text_w)/2:y=440:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='✅ Escalabilidade: HPA Configurado':fontcolor=#10b981:fontsize=48:x=(w-text_w)/2:y=520:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,
                drawtext=text='✅ Observabilidade: 360° Monitoring':fontcolor=#10b981:fontsize=48:x=(w-text_w)/2:y=600:fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" \
           -y "$output_file" 2>/dev/null
    
    echo "$output_file"
}

# Função principal para criar todos os slides
create_all_slides() {
    log "Criando slides introdutórios..."
    
    # Criar diretório de slides
    mkdir -p "$SLIDES_DIR"
    
    # Slide 1: Título principal
    create_slide 1 "FIAP-X" "Sistema de Processamento de Vídeos" 4 "#1e3a8a" "white"
    
    # Slide 2: Equipe
    create_multiline_slide 2 "EQUIPE DE DESENVOLVIMENTO" \
        "• Henrique Moraes - Arquiteto de Soluções" \
        "• Especialização: Cloud Native & Kubernetes" \
        "• Tecnologias: Go, React, AWS, Docker" \
        "• Foco: Microsserviços & Observabilidade" 4 "#7c3aed"
    
    # Slide 3: Objetivos
    create_multiline_slide 3 "OBJETIVOS DO PROJETO" \
        "• Sistema escalável de processamento de vídeos" \
        "• Arquitetura de microsserviços resiliente" \
        "• Implementação de observabilidade completa" \
        "• Deploy automatizado com CI/CD" 4 "#dc2626"
    
    # Slide 4: Arquitetura
    create_architecture_slide 4 6
    
    # Slide 5: Tecnologias
    create_multiline_slide 5 "STACK TECNOLÓGICO" \
        "• Backend: Go (Gin) + PostgreSQL + Redis" \
        "• Frontend: React + Bootstrap + JavaScript" \
        "• Infra: Kubernetes + AWS + Docker" \
        "• Observabilidade: Prometheus + Grafana" 4 "#0891b2"
    
    # Slide 6: Métricas
    create_metrics_slide 6 5
    
    # Slide 7: Agenda
    create_multiline_slide 7 "AGENDA DA APRESENTAÇÃO" \
        "1. Documentação e Arquitetura (2 min)" \
        "2. Ambiente e Infraestrutura (1.5 min)" \
        "3. Demonstração Prática (4 min)" \
        "4. Observabilidade e CI/CD (3.5 min)" 4 "#ea580c"
    
    # Slide 8: Transição
    create_slide 8 "VAMOS COMEÇAR!" "Demonstração ao vivo do sistema" 3 "#16a34a" "white"
    
    log "✅ Todos os slides criados em: $SLIDES_DIR"
}

# Função para combinar slides
combine_slides() {
    log "Combinando slides em vídeo único..."
    
    local concat_file="$SLIDES_DIR/slides_concat.txt"
    echo "# Lista de slides para concatenar" > "$concat_file"
    
    # Adicionar todos os slides
    for i in {1..8}; do
        if [[ -f "$SLIDES_DIR/slide_$i.mp4" ]]; then
            echo "file '$SLIDES_DIR/slide_$i.mp4'" >> "$concat_file"
        fi
    done
    
    # Combinar slides
    local intro_video="$OUTPUT_DIR/fiapx-intro-slides.mp4"
    ffmpeg -f concat -safe 0 -i "$concat_file" -c copy "$intro_video" -y 2>/dev/null
    
    log "✅ Vídeo de introdução criado: $intro_video"
    echo "$intro_video"
}

# Função para criar vídeo final completo
create_complete_video() {
    local intro_video="$1"
    local main_video="$2"
    
    if [[ ! -f "$main_video" ]]; then
        log "Vídeo principal não encontrado: $main_video"
        return 1
    fi
    
    log "Criando vídeo completo com introdução..."
    
    # Criar lista de concatenação
    local complete_concat="$OUTPUT_DIR/complete_concat.txt"
    echo "file '$intro_video'" > "$complete_concat"
    echo "file '$main_video'" >> "$complete_concat"
    
    # Vídeo final
    local final_video="$OUTPUT_DIR/fiapx-presentation-complete-$(date +%Y%m%d_%H%M%S).mp4"
    ffmpeg -f concat -safe 0 -i "$complete_concat" -c copy "$final_video" -y 2>/dev/null
    
    log "✅ Vídeo completo criado: $final_video"
    echo "$final_video"
}

# Função para exibir ajuda
show_help() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Opções:"
    echo "  --slides-only     Criar apenas slides introdutórios"
    echo "  --combine <video> Combinar slides com vídeo existente"
    echo "  -h, --help        Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                                    # Criar slides"
    echo "  $0 --slides-only                     # Apenas slides"
    echo "  $0 --combine video.mp4               # Slides + vídeo"
    echo ""
}

# Função principal
main() {
    local slides_only=false
    local combine_video=""
    
    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --slides-only)
                slides_only=true
                shift
                ;;
            --combine)
                combine_video="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar FFmpeg
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}❌ FFmpeg não encontrado${NC}"
        echo "Instale com: sudo apt-get install ffmpeg"
        exit 1
    fi
    
    # Criar diretórios
    mkdir -p "$OUTPUT_DIR" "$SLIDES_DIR"
    
    # Criar slides
    create_all_slides
    local intro_video=$(combine_slides)
    
    if [[ "$slides_only" == "true" ]]; then
        log "✅ Slides criados com sucesso!"
        echo "Vídeo de introdução: $intro_video"
        exit 0
    fi
    
    # Combinar com vídeo existente se especificado
    if [[ -n "$combine_video" ]]; then
        if [[ -f "$combine_video" ]]; then
            create_complete_video "$intro_video" "$combine_video"
        else
            echo -e "${RED}❌ Vídeo não encontrado: $combine_video${NC}"
            exit 1
        fi
    else
        log "✅ Slides introdutórios prontos!"
        echo "Para combinar com vídeo principal:"
        echo "  $0 --combine /path/to/main/video.mp4"
    fi
}

# Executar função principal
main "$@"
