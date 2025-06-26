#!/bin/bash

# Script para transferir imagens Docker para o cluster remoto
# Autor: GitHub Copilot
# Data: 26/06/2025

echo "🚀 Transferindo imagens para o cluster remoto..."

REMOTE_HOST="ubuntu@worker.wecando.click"
SSH_KEY="~/.ssh/keyPrincipal.pem"

# Função para transferir imagem
transfer_image() {
    local service_name=$1
    local image_tag="fiapx/${service_name}:latest"
    local tar_file="/tmp/${service_name}.tar"
    
    echo "📦 Processando ${service_name}..."
    
    # Verificar se a imagem existe
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "${image_tag}"; then
        echo "  ✅ Imagem encontrada: ${image_tag}"
        
        # Salvar imagem como tar
        echo "  💾 Salvando imagem como tar..."
        docker save "${image_tag}" -o "${tar_file}"
        
        # Transferir para o cluster
        echo "  📡 Transferindo para o cluster..."
        scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${tar_file}" "${REMOTE_HOST}:/tmp/"
        
        # Carregar imagem no cluster
        echo "  📥 Carregando imagem no cluster..."
        ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${REMOTE_HOST}" "docker load -i /tmp/${service_name}.tar"
        
        # Limpar arquivo temporário local
        rm -f "${tar_file}"
        
        # Limpar arquivo temporário remoto
        ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${REMOTE_HOST}" "rm -f /tmp/${service_name}.tar"
        
        echo "  ✅ ${service_name} transferido com sucesso!"
        
    else
        echo "  ❌ Imagem não encontrada: ${image_tag}"
    fi
    
    echo ""
}

# Lista de serviços
services=("upload-service" "processing-service" "storage-service")

# Transferir cada serviço
for service in "${services[@]}"; do
    transfer_image "$service"
done

echo "🎉 Transferência concluída!"
echo ""
echo "📋 Verificando imagens no cluster:"
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${REMOTE_HOST}" "docker images | grep fiapx"
