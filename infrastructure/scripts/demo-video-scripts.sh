#!/bin/bash

# =============================================================================
# Demo e Testes dos Scripts de Geração de Vídeo - FIAP-X
# =============================================================================
# Descrição: Demonstra e testa todos os scripts de geração de vídeo
# Uso: ./demo-video-scripts.sh
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
DEMO_START_TIME=$(date +%s)

# Função para exibir header
show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                   🎬 DEMO - SCRIPTS DE VÍDEO FIAP-X 🎬                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Função para log
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para separador visual
separator() {
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Função para pausar e aguardar input
pause() {
    echo ""
    echo -e "${YELLOW}Pressione ENTER para continuar...${NC}"
    read -r
}

# Demo 1: Verificar ambiente
demo_check_environment() {
    show_header
    echo -e "${CYAN}🔍 DEMO 1: VERIFICAÇÃO DO AMBIENTE${NC}"
    separator
    
    log "Verificando dependências básicas..."
    
    # Verificar scripts
    local scripts=(
        "generate-presentation-video.sh"
        "setup-video-recording.sh"
        "video-recording-controller.sh"
        "generate-intro-slides.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            log_info "✅ $script - Executável"
        else
            log_error "❌ $script - Não encontrado ou não executável"
        fi
    done
    
    echo ""
    log "Verificando ferramentas do sistema..."
    
    # Verificar ferramentas
    local tools=(
        "ffmpeg:Gravação de vídeo"
        "xwininfo:Captura de janelas"
        "xdotool:Automação de interface"
        "kubectl:Kubernetes CLI"
        "ssh:Acesso remoto"
        "curl:Testes de conectividade"
    )
    
    for tool_info in "${tools[@]}"; do
        local tool=$(echo "$tool_info" | cut -d: -f1)
        local desc=$(echo "$tool_info" | cut -d: -f2)
        
        if command -v "$tool" &> /dev/null; then
            log_info "✅ $tool - $desc"
        else
            log_warn "⚠️  $tool - $desc (não encontrado)"
        fi
    done
    
    pause
}

# Demo 2: Testar scripts com --help
demo_help_commands() {
    show_header
    echo -e "${CYAN}📖 DEMO 2: COMANDOS DE AJUDA${NC}"
    separator
    
    local scripts=(
        "generate-presentation-video.sh"
        "generate-intro-slides.sh"
    )
    
    for script in "${scripts[@]}"; do
        log "Testando: $script --help"
        echo ""
        
        if [[ -x "$SCRIPT_DIR/$script" ]]; then
            "$SCRIPT_DIR/$script" --help || true
        else
            log_error "Script não encontrado: $script"
        fi
        
        separator
    done
    
    pause
}

# Demo 3: Simulação rápida
demo_quick_simulation() {
    show_header
    echo -e "${CYAN}🧪 DEMO 3: SIMULAÇÃO RÁPIDA${NC}"
    separator
    
    log "Executando simulação de 1 minuto..."
    echo ""
    
    if [[ -x "$SCRIPT_DIR/generate-presentation-video.sh" ]]; then
        "$SCRIPT_DIR/generate-presentation-video.sh" 1 --simulate --no-setup
    else
        log_error "Script principal não encontrado"
    fi
    
    pause
}

# Demo 4: Geração de slides
demo_generate_slides() {
    show_header
    echo -e "${CYAN}🎨 DEMO 4: GERAÇÃO DE SLIDES${NC}"
    separator
    
    log "Gerando slides introdutórios..."
    echo ""
    
    if [[ -x "$SCRIPT_DIR/generate-intro-slides.sh" ]]; then
        "$SCRIPT_DIR/generate-intro-slides.sh" --slides-only
        
        echo ""
        log "Verificando slides gerados..."
        local slides_dir="$PROJECT_ROOT/outputs/presentation-video/slides"
        
        if [[ -d "$slides_dir" ]]; then
            ls -la "$slides_dir"/*.mp4 2>/dev/null || log_warn "Nenhum slide MP4 encontrado"
        else
            log_warn "Diretório de slides não encontrado"
        fi
        
        # Verificar vídeo de introdução
        local intro_video="$PROJECT_ROOT/outputs/presentation-video/fiapx-intro-slides.mp4"
        if [[ -f "$intro_video" ]]; then
            local size=$(du -h "$intro_video" | cut -f1)
            log_info "✅ Vídeo de introdução criado: $size"
        else
            log_warn "Vídeo de introdução não encontrado"
        fi
    else
        log_error "Script de slides não encontrado"
    fi
    
    pause
}

# Demo 5: Testar seção específica
demo_specific_section() {
    show_header
    echo -e "${CYAN}📋 DEMO 5: GRAVAÇÃO DE SEÇÃO ESPECÍFICA${NC}"
    separator
    
    log "Testando gravação da Seção 1 (Documentação) em simulação..."
    echo ""
    
    if [[ -x "$SCRIPT_DIR/generate-presentation-video.sh" ]]; then
        "$SCRIPT_DIR/generate-presentation-video.sh" 2 --section 1 --simulate --no-setup
    else
        log_error "Script principal não encontrado"
    fi
    
    pause
}

# Demo 6: Verificar conectividade
demo_connectivity() {
    show_header
    echo -e "${CYAN}🌐 DEMO 6: TESTE DE CONECTIVIDADE${NC}"
    separator
    
    log "Testando conectividade com serviços..."
    echo ""
    
    # Frontend
    echo -n "Frontend (fiapx.wecando.click): "
    if curl -s --max-time 10 https://fiapx.wecando.click > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Acessível${NC}"
    else
        echo -e "${RED}❌ Inacessível${NC}"
    fi
    
    # AWS (ping básico)
    echo -n "AWS Host (worker.wecando.click): "
    if ping -c 1 -W 5 worker.wecando.click > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Alcançável${NC}"
    else
        echo -e "${RED}❌ Inalcançável${NC}"
    fi
    
    # Kubernetes (se disponível)
    echo -n "Kubectl: "
    if command -v kubectl &> /dev/null; then
        if kubectl version --client &> /dev/null; then
            echo -e "${GREEN}✅ Disponível${NC}"
        else
            echo -e "${YELLOW}⚠️  Disponível mas sem contexto${NC}"
        fi
    else
        echo -e "${RED}❌ Não instalado${NC}"
    fi
    
    # Serviços locais
    echo -n "Grafana local (localhost:3000): "
    if curl -s --max-time 3 http://localhost:3000 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Rodando${NC}"
    else
        echo -e "${YELLOW}⚠️  Não disponível (port-forward necessário)${NC}"
    fi
    
    echo -n "Prometheus local (localhost:9090): "
    if curl -s --max-time 3 http://localhost:9090 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Rodando${NC}"
    else
        echo -e "${YELLOW}⚠️  Não disponível (port-forward necessário)${NC}"
    fi
    
    pause
}

# Demo 7: Estrutura de arquivos
demo_file_structure() {
    show_header
    echo -e "${CYAN}📁 DEMO 7: ESTRUTURA DE ARQUIVOS${NC}"
    separator
    
    log "Mostrando estrutura de arquivos do projeto..."
    echo ""
    
    # Scripts
    echo -e "${PURPLE}📜 Scripts disponíveis:${NC}"
    ls -la "$SCRIPT_DIR"/*.sh 2>/dev/null || log_warn "Nenhum script encontrado"
    
    echo ""
    
    # Documentação
    echo -e "${PURPLE}📖 Documentação:${NC}"
    ls -la "$SCRIPT_DIR"/*.md 2>/dev/null || log_warn "Nenhuma documentação encontrada"
    
    echo ""
    
    # Outputs
    echo -e "${PURPLE}📁 Diretório de outputs:${NC}"
    local outputs_dir="$PROJECT_ROOT/outputs/presentation-video"
    if [[ -d "$outputs_dir" ]]; then
        echo "Conteúdo de $outputs_dir:"
        ls -la "$outputs_dir" 2>/dev/null || echo "  (vazio)"
        
        # Slides se existirem
        if [[ -d "$outputs_dir/slides" ]]; then
            echo ""
            echo "Slides:"
            ls -la "$outputs_dir/slides"/*.mp4 2>/dev/null || echo "  (nenhum slide)"
        fi
    else
        log_info "Diretório será criado automaticamente na primeira execução"
    fi
    
    pause
}

# Demo 8: Estatísticas finais
demo_final_stats() {
    show_header
    echo -e "${CYAN}📊 DEMO 8: ESTATÍSTICAS FINAIS${NC}"
    separator
    
    local demo_end_time=$(date +%s)
    local demo_duration=$((demo_end_time - DEMO_START_TIME))
    local demo_minutes=$((demo_duration / 60))
    local demo_seconds=$((demo_duration % 60))
    
    log "Resumo da demonstração:"
    echo ""
    
    echo -e "⏱️  ${YELLOW}Duração total da demo:${NC} ${demo_minutes}m${demo_seconds}s"
    echo -e "📜 ${YELLOW}Scripts testados:${NC} 4"
    echo -e "🧪 ${YELLOW}Testes executados:${NC} 8"
    echo -e "📁 ${YELLOW}Arquivos verificados:${NC} $(find "$SCRIPT_DIR" -name "*.sh" -o -name "*.md" | wc -l)"
    
    echo ""
    echo -e "${GREEN}✅ Demos concluídas com sucesso!${NC}"
    
    echo ""
    echo -e "${BLUE}🎯 Próximos passos sugeridos:${NC}"
    echo "1. Execute ./setup-video-recording.sh para configurar o ambiente"
    echo "2. Use ./video-recording-controller.sh para gravação interativa"
    echo "3. Teste com ./generate-presentation-video.sh 5 --simulate"
    echo "4. Produza vídeo real com ./generate-presentation-video.sh 10"
    
    echo ""
    echo -e "${PURPLE}📚 Documentação completa em: README-video-scripts.md${NC}"
    
    pause
}

# Menu principal
show_main_menu() {
    show_header
    echo -e "${GREEN}🎯 ESCOLHA UMA DEMONSTRAÇÃO:${NC}"
    echo ""
    echo "  1) 🔍 Verificar ambiente e dependências"
    echo "  2) 📖 Testar comandos de ajuda"
    echo "  3) 🧪 Simulação rápida (1 min)"
    echo "  4) 🎨 Gerar slides introdutórios"
    echo "  5) 📋 Testar seção específica"
    echo "  6) 🌐 Verificar conectividade"
    echo "  7) 📁 Mostrar estrutura de arquivos"
    echo "  8) 📊 Estatísticas e resumo"
    echo ""
    echo "  a) 🚀 Executar TODAS as demos"
    echo "  h) 📖 Mostrar ajuda"
    echo "  q) 🚪 Sair"
    echo ""
}

# Função para executar todas as demos
run_all_demos() {
    log "Executando todas as demonstrações..."
    
    demo_check_environment
    demo_help_commands
    demo_quick_simulation
    demo_generate_slides
    demo_specific_section
    demo_connectivity
    demo_file_structure
    demo_final_stats
    
    log "✅ Todas as demonstrações concluídas!"
}

# Função para mostrar ajuda
show_help() {
    show_header
    echo -e "${BLUE}📖 AJUDA - DEMO DOS SCRIPTS DE VÍDEO${NC}"
    separator
    
    echo "Este script demonstra todas as funcionalidades dos scripts de geração"
    echo "de vídeo do projeto FIAP-X."
    echo ""
    echo "🎯 Demos disponíveis:"
    echo ""
    echo "1. Verificação do Ambiente"
    echo "   - Verifica se todos os scripts estão presentes"
    echo "   - Testa dependências do sistema"
    echo ""
    echo "2. Comandos de Ajuda"
    echo "   - Executa --help de todos os scripts"
    echo "   - Mostra opções disponíveis"
    echo ""
    echo "3. Simulação Rápida"
    echo "   - Executa simulação de 1 minuto"
    echo "   - Não grava arquivos reais"
    echo ""
    echo "4. Geração de Slides"
    echo "   - Cria slides introdutórios"
    echo "   - Combina em vídeo único"
    echo ""
    echo "5. Seção Específica"
    echo "   - Testa gravação de uma seção"
    echo "   - Modo simulação"
    echo ""
    echo "6. Verificar Conectividade"
    echo "   - Testa acesso aos serviços"
    echo "   - Valida configuração de rede"
    echo ""
    echo "7. Estrutura de Arquivos"
    echo "   - Mostra organização do projeto"
    echo "   - Lista arquivos gerados"
    echo ""
    echo "8. Estatísticas Finais"
    echo "   - Resumo da execução"
    echo "   - Próximos passos"
    echo ""
    
    pause
}

# Loop principal
main_loop() {
    while true; do
        show_main_menu
        
        echo -n -e "${CYAN}Digite sua escolha: ${NC}"
        read -r choice
        
        case $choice in
            1) demo_check_environment ;;
            2) demo_help_commands ;;
            3) demo_quick_simulation ;;
            4) demo_generate_slides ;;
            5) demo_specific_section ;;
            6) demo_connectivity ;;
            7) demo_file_structure ;;
            8) demo_final_stats ;;
            a|A) run_all_demos ;;
            h|H) show_help ;;
            q|Q) 
                echo -e "${GREEN}👋 Demo finalizada. Obrigado!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opção inválida: $choice${NC}"
                sleep 2
                ;;
        esac
    done
}

# Função principal
main() {
    # Verificar se estamos no diretório correto
    if [[ ! -f "$SCRIPT_DIR/generate-presentation-video.sh" ]]; then
        log_error "Scripts de vídeo não encontrados neste diretório"
        echo "Certifique-se de executar este script do diretório infrastructure/scripts/"
        exit 1
    fi
    
    # Iniciar demo
    main_loop
}

# Executar
main "$@"
