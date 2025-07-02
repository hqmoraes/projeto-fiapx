#!/bin/bash

# Script para combinar seções de vídeo já gravadas
# Uso: ./combine-video-sections.sh [OUTPUT_NAME]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/outputs/videos"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Parâmetros
OUTPUT_NAME=${1:-"fiapx-demo-combined-$(date +%Y%m%d-%H%M%S)"}

print_color $BLUE "🎬 Combinando seções de vídeo..."
print_color $YELLOW "📁 Diretório: $OUTPUT_DIR"
print_color $YELLOW "📄 Output: ${OUTPUT_NAME}.mp4"

cd "$OUTPUT_DIR"

# Verificar se existem arquivos de seção
SECTION_FILES=($(ls *_abertura.mp4 *_documentacao.mp4 *_infraestrutura.mp4 *_usuario.mp4 *_upload.mp4 *_observabilidade.mp4 *_cicd.mp4 *_download.mp4 *_encerramento.mp4 2>/dev/null || true))

if [ ${#SECTION_FILES[@]} -eq 0 ]; then
    print_color $RED "❌ Nenhum arquivo de seção encontrado!"
    print_color $YELLOW "💡 Execute primeiro: ./generate-demo-video.sh --mode sections"
    exit 1
fi

print_color $GREEN "✅ Encontrados ${#SECTION_FILES[@]} arquivos de seção"

# Criar lista de concatenação
CONCAT_LIST="concat_list_$(date +%s).txt"
echo "# Lista de concatenação gerada automaticamente" > "$CONCAT_LIST"

# Ordenar seções na ordem correta
declare -A section_order=(
    ["abertura"]=1
    ["documentacao"]=2  
    ["infraestrutura"]=3
    ["usuario"]=4
    ["upload"]=5
    ["observabilidade"]=6
    ["cicd"]=7
    ["download"]=8
    ["encerramento"]=9
)

# Encontrar arquivos por seção em ordem
for section in abertura documentacao infraestrutura usuario upload observabilidade cicd download encerramento; do
    SECTION_FILE=$(ls *_${section}.mp4 2>/dev/null | head -1 || true)
    if [ -n "$SECTION_FILE" ]; then
        echo "file '$SECTION_FILE'" >> "$CONCAT_LIST"
        print_color $GREEN "  ✅ Adicionado: $SECTION_FILE"
    else
        print_color $YELLOW "  ⚠️  Seção '$section' não encontrada, pulando..."
    fi
done

# Verificar se temos pelo menos uma seção
if [ ! -s "$CONCAT_LIST" ]; then
    print_color $RED "❌ Nenhuma seção válida encontrada para concatenação!"
    rm -f "$CONCAT_LIST"
    exit 1
fi

print_color $BLUE "🔄 Executando concatenação com ffmpeg..."

# Executar concatenação
if ffmpeg -f concat -safe 0 -i "$CONCAT_LIST" -c copy "${OUTPUT_NAME}.mp4" -y; then
    print_color $GREEN "✅ Vídeo combinado criado com sucesso!"
    print_color $BLUE "📄 Arquivo final: ${OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
    
    # Mostrar informações do arquivo
    if command -v ffprobe >/dev/null 2>&1; then
        echo ""
        print_color $BLUE "📊 Informações do vídeo:"
        ffprobe -v quiet -show_format -show_streams "${OUTPUT_NAME}.mp4" | grep -E "(duration|width|height|codec_name)" | head -10
    fi
    
    # Mostrar tamanho do arquivo
    FILE_SIZE=$(du -h "${OUTPUT_NAME}.mp4" | cut -f1)
    print_color $BLUE "📦 Tamanho: $FILE_SIZE"
    
else
    print_color $RED "❌ Erro na concatenação do vídeo!"
    rm -f "$CONCAT_LIST"
    exit 1
fi

# Limpeza opcional
echo ""
read -p "Deseja remover os arquivos de seção individuais? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for file in "${SECTION_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            print_color $YELLOW "🗑️  Removido: $file"
        fi
    done
    print_color $GREEN "✅ Arquivos de seção removidos"
fi

rm -f "$CONCAT_LIST"

echo ""
print_color $GREEN "🎉 Processo concluído!"
print_color $BLUE "🎬 Vídeo final disponível em:"
print_color $BLUE "   ${OUTPUT_DIR}/${OUTPUT_NAME}.mp4"
