#!/bin/bash

# =============================================================================
# Script para Configuração de Ambiente de Gravação de Vídeo
# =============================================================================
# Descrição: Prepara o ambiente para gravação automatizada de vídeos
# Uso: ./setup-video-recording.sh
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

# Função para detectar distro
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Função para instalar dependências no Ubuntu/Debian
install_ubuntu_deps() {
    log "Instalando dependências no Ubuntu/Debian..."
    
    sudo apt-get update
    
    # Ferramentas de gravação de vídeo
    sudo apt-get install -y \
        ffmpeg \
        x11-utils \
        xdotool \
        scrot \
        gnome-screenshot \
        imagemagick \
        pulseaudio-utils
    
    # Browsers para demonstração
    if ! command -v firefox &> /dev/null; then
        sudo apt-get install -y firefox
    fi
    
    # Ferramentas de terminal
    if ! command -v gnome-terminal &> /dev/null && ! command -v xterm &> /dev/null; then
        sudo apt-get install -y gnome-terminal
    fi
    
    log "✅ Dependências Ubuntu/Debian instaladas"
}

# Função para instalar dependências no CentOS/RHEL/Fedora
install_rhel_deps() {
    log "Instalando dependências no RHEL/CentOS/Fedora..."
    
    # Detectar gerenciador de pacotes
    if command -v dnf &> /dev/null; then
        local pkg_mgr="dnf"
    elif command -v yum &> /dev/null; then
        local pkg_mgr="yum"
    else
        log_error "Gerenciador de pacotes não encontrado"
        return 1
    fi
    
    # Instalar RPM Fusion para ffmpeg
    sudo $pkg_mgr install -y \
        https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm || true
    
    # Ferramentas de gravação
    sudo $pkg_mgr install -y \
        ffmpeg \
        xorg-x11-utils \
        xdotool \
        scrot \
        ImageMagick \
        pulseaudio-utils
    
    # Browsers
    if ! command -v firefox &> /dev/null; then
        sudo $pkg_mgr install -y firefox
    fi
    
    log "✅ Dependências RHEL/CentOS/Fedora instaladas"
}

# Função para instalar dependências no Arch Linux
install_arch_deps() {
    log "Instalando dependências no Arch Linux..."
    
    sudo pacman -Syu --noconfirm \
        ffmpeg \
        xorg-xwininfo \
        xdotool \
        scrot \
        imagemagick \
        pulseaudio \
        firefox
    
    log "✅ Dependências Arch Linux instaladas"
}

# Função para configurar resolução de tela
configure_screen_resolution() {
    log "Configurando resolução de tela para gravação..."
    
    local current_resolution=$(xdpyinfo | grep dimensions | awk '{print $2}')
    log "Resolução atual: $current_resolution"
    
    # Verificar se a resolução é adequada para gravação
    local width=$(echo $current_resolution | cut -d'x' -f1)
    local height=$(echo $current_resolution | cut -d'x' -f2)
    
    if [[ $width -lt 1920 ]] || [[ $height -lt 1080 ]]; then
        log_warn "Resolução atual ($current_resolution) pode não ser ideal para gravação"
        log_warn "Recomendada: 1920x1080 ou superior"
        
        # Tentar configurar resolução maior se disponível
        if xrandr | grep -q "1920x1080"; then
            log "Configurando resolução para 1920x1080..."
            xrandr --output $(xrandr | grep " connected" | cut -d" " -f1 | head -1) --mode 1920x1080 || true
        fi
    fi
    
    log "✅ Resolução configurada"
}

# Função para configurar áudio
configure_audio() {
    log "Configurando captura de áudio..."
    
    # Verificar se PulseAudio está rodando
    if ! pulseaudio --check; then
        log "Iniciando PulseAudio..."
        pulseaudio --start
    fi
    
    # Listar dispositivos de áudio
    log "Dispositivos de áudio disponíveis:"
    pactl list short sources | head -5
    
    log "✅ Áudio configurado"
}

# Função para configurar variáveis de ambiente
configure_environment() {
    log "Configurando variáveis de ambiente..."
    
    # Criar arquivo de configuração para o usuário
    local config_file="$HOME/.fiapx-video-config"
    
    cat > "$config_file" << EOF
# Configurações para gravação de vídeo FIAP-X
export DISPLAY=\${DISPLAY:-:0}
export FIAPX_VIDEO_QUALITY=high
export FIAPX_VIDEO_FPS=30
export FIAPX_AUDIO_ENABLED=true
export FIAPX_SCREEN_RESOLUTION=$(xdpyinfo | grep dimensions | awk '{print $2}')

# Paths importantes
export FIAPX_PROJECT_ROOT="$PROJECT_ROOT"
export FIAPX_OUTPUT_DIR="$PROJECT_ROOT/outputs/presentation-video"

# AWS/K8s configurações
export FIAPX_AWS_HOST="worker.wecando.click"
export FIAPX_SSH_KEY="\$HOME/.ssh/keyPrincipal.pem"
export FIAPX_FRONTEND_URL="https://fiapx.wecando.click"
EOF
    
    log "✅ Configurações salvas em: $config_file"
    log "Para usar as configurações, execute: source $config_file"
}

# Função para testar configuração
test_configuration() {
    log "Testando configuração do ambiente..."
    
    # Testar captura de tela
    log "Testando captura de tela..."
    local test_screenshot="/tmp/fiapx_test_screenshot.png"
    
    if command -v scrot &> /dev/null; then
        scrot "$test_screenshot" 2>/dev/null && rm -f "$test_screenshot" && log "✅ Captura de tela: OK"
    elif command -v gnome-screenshot &> /dev/null; then
        gnome-screenshot -f "$test_screenshot" 2>/dev/null && rm -f "$test_screenshot" && log "✅ Captura de tela: OK"
    else
        log_warn "Nenhuma ferramenta de captura de tela encontrada"
    fi
    
    # Testar FFmpeg
    log "Testando FFmpeg..."
    if ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -f null - &>/dev/null; then
        log "✅ FFmpeg: OK"
    else
        log_warn "FFmpeg pode não estar funcionando corretamente"
    fi
    
    # Testar xdotool
    log "Testando xdotool..."
    if xdotool search --name "." &>/dev/null; then
        log "✅ xdotool: OK"
    else
        log_warn "xdotool pode não estar funcionando corretamente"
    fi
    
    # Testar conectividade (opcional)
    log "Testando conectividade..."
    if ping -c 1 google.com &>/dev/null; then
        log "✅ Conectividade: OK"
    else
        log_warn "Conectividade limitada - algumas funcionalidades podem não funcionar"
    fi
    
    log "✅ Testes de configuração concluídos"
}

# Função para criar diretórios necessários
create_directories() {
    log "Criando diretórios necessários..."
    
    local dirs=(
        "$PROJECT_ROOT/outputs/presentation-video"
        "$PROJECT_ROOT/outputs/presentation-video/temp"
        "$PROJECT_ROOT/outputs/screenshots"
        "$PROJECT_ROOT/outputs/audio-recordings"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log "📁 Criado: $dir"
    done
    
    log "✅ Diretórios criados"
}

# Função para exibir ajuda pós-instalação
show_post_install_help() {
    echo ""
    echo -e "${BLUE}=== Configuração Concluída ===${NC}"
    echo ""
    echo "Para usar o sistema de gravação de vídeo:"
    echo ""
    echo "1. Carregue as configurações:"
    echo "   source ~/.fiapx-video-config"
    echo ""
    echo "2. Execute o gerador de vídeo:"
    echo "   ./generate-presentation-video.sh 10  # Para 10 minutos"
    echo ""
    echo "3. Opções disponíveis:"
    echo "   ./generate-presentation-video.sh --help"
    echo ""
    echo "4. Teste em modo simulação primeiro:"
    echo "   ./generate-presentation-video.sh 5 --simulate"
    echo ""
    echo "📁 Vídeos serão salvos em: $PROJECT_ROOT/outputs/presentation-video/"
    echo ""
    echo -e "${GREEN}✅ Ambiente configurado com sucesso!${NC}"
    echo ""
}

# Função principal
main() {
    log "🎬 Configurando ambiente de gravação de vídeo FIAP-X"
    
    # Detectar sistema operacional
    local distro=$(detect_distro)
    log "Sistema detectado: $distro"
    
    # Instalar dependências baseado na distro
    case $distro in
        ubuntu|debian)
            install_ubuntu_deps
            ;;
        rhel|centos|fedora)
            install_rhel_deps
            ;;
        arch|manjaro)
            install_arch_deps
            ;;
        *)
            log_warn "Distribuição não reconhecida: $distro"
            log_warn "Você precisará instalar as dependências manualmente:"
            echo "  - ffmpeg"
            echo "  - x11-utils (xwininfo)"
            echo "  - xdotool"
            echo "  - scrot ou gnome-screenshot"
            echo "  - imagemagick"
            echo "  - pulseaudio-utils"
            echo "  - firefox"
            ;;
    esac
    
    # Configurar ambiente
    create_directories
    configure_screen_resolution
    configure_audio
    configure_environment
    test_configuration
    
    # Mostrar ajuda
    show_post_install_help
}

# Executar função principal
main "$@"
