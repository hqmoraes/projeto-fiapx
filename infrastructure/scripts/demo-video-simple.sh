#!/bin/bash

# Script simplificado para demonstrar a geração de vídeo
# Uso: ./demo-video-simple.sh [DURATION_MINUTES]

set -e

DURATION=${1:-10}
OUTPUT_DIR="$(pwd)/outputs/videos"
mkdir -p "$OUTPUT_DIR"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

print_color $CYAN "
╔══════════════════════════════════════════════════════════════╗
║                FIAP-X Demo Video Generator                   ║
║                    (Versão Simplificada)                    ║
╚══════════════════════════════════════════════════════════════╝
"

print_color $BLUE "⚙️  Configuração:"
echo "  - Duração: ${DURATION} minutos"
echo "  - Output: $OUTPUT_DIR"
echo ""

# Calcular tempos das seções proporcionalmente
total_seconds=$((DURATION * 60))
base_seconds=630  # 10min 30s base

declare -A sections=(
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

print_color $BLUE "📋 Seções planejadas:"
total_calculated=0

for section in abertura documentacao infraestrutura usuario upload observabilidade cicd download encerramento; do
    # Calcular tempo proporcional
    base_time=${sections[$section]}
    new_time=$((base_time * total_seconds / base_seconds))
    total_calculated=$((total_calculated + new_time))
    
    echo "  $(printf "%-15s" "$section"): ${new_time}s (base: ${base_time}s)"
done

echo ""
print_color $YELLOW "⏱️  Total calculado: ${total_calculated}s (${DURATION} minutos = ${total_seconds}s)"

echo ""
print_color $BLUE "🎬 Comandos que seriam executados:"
echo ""

print_color $CYAN "1. ABERTURA (30s):"
echo "   - Abrir ROTEIRO-VIDEO-APRESENTACAO.md"
echo "   - Navegação inicial"
echo "   - Narração de introdução"
echo ""

print_color $CYAN "2. DOCUMENTAÇÃO (2min):"
echo "   - Abrir DOCUMENTACAO-ARQUITETURA.md"
echo "   - Mostrar diagrama de arquitetura"
echo "   - Destacar funcionalidades implementadas"
echo ""

print_color $CYAN "3. INFRAESTRUTURA (1min 30s):"
echo "   - ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click"
echo "   - kubectl get pods -A"
echo "   - kubectl get svc -n fiapx"
echo "   - kubectl get hpa -n fiapx"
echo ""

print_color $CYAN "4. CRIAÇÃO DE USUÁRIO (1min):"
echo "   - Abrir https://fiapx.wecando.click"
echo "   - Simular cadastro de usuário"
echo "   - Login com JWT"
echo ""

print_color $CYAN "5. UPLOAD E PROCESSAMENTO (2min):"
echo "   - Upload de vídeos múltiplos"
echo "   - Acompanhar status em tempo real"
echo "   - Mostrar processamento paralelo"
echo ""

print_color $CYAN "6. OBSERVABILIDADE (2min):"
echo "   - kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo "   - Abrir http://localhost:9090"
echo "   - kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo "   - Abrir http://localhost:3000"
echo "   - Demonstrar dashboards"
echo ""

print_color $CYAN "7. CI/CD E AUTO-SCALING (1min 30s):"
echo "   - Abrir GitHub Actions"
echo "   - Mostrar pipeline executando"
echo "   - Demonstrar HPA em ação"
echo ""

print_color $CYAN "8. DOWNLOAD (45s):"
echo "   - Download de resultados"
echo "   - Mostrar frames extraídos"
echo ""

print_color $CYAN "9. ENCERRAMENTO (30s):"
echo "   - Resumo final"
echo "   - Conclusão"
echo ""

print_color $GREEN "✅ Simulação concluída!"
print_color $BLUE "📋 Para executar a gravação real:"
echo "  1. Instale dependências: ./infrastructure/scripts/install-video-dependencies.sh"
echo "  2. Execute gravação: ./infrastructure/scripts/generate-demo-video.sh $DURATION"
echo ""
print_color $YELLOW "💡 Comandos manuais para gravação:"
echo "  # Gravação de tela com ffmpeg"
echo "  ffmpeg -f x11grab -s 1920x1080 -r 30 -i :0.0 -f pulse -i default output.mp4"
echo ""
echo "  # Ou use OBS Studio para maior controle"
echo "  obs-studio"
