#!/bin/bash

# Script para configurar HTTPS para fiapx.wecando.click
# Configura DNS e deploy no cluster Kubernetes

set -e

echo "🚀 Configurando HTTPS para fiapx.wecando.click"
echo "=================================================="

# IPs dos nós do cluster (corretos)
WORKER_IP="54.210.189.246"  # worker.wecando.click
MASTER_IP="44.210.118.109"  # master.wecando.click

echo "📍 Worker IP: $WORKER_IP"
echo "📍 Master IP: $MASTER_IP"

# Configurar DNS no Route53
echo "🌐 Configurando DNS para fiapx.wecando.click..."

# Verificar se o AWS CLI está configurado
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI não está configurado. Execute: aws configure"
    exit 1
fi

# Obter Hosted Zone ID para wecando.click
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='wecando.click.'].Id" --output text | cut -d'/' -f3)

if [ -z "$ZONE_ID" ]; then
    echo "❌ Hosted Zone para wecando.click não encontrada"
    exit 1
fi

echo "✅ Hosted Zone ID: $ZONE_ID"

# Criar registro DNS para fiapx.wecando.click apontando para o worker
echo "📝 Criando registro DNS..."

aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "{
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"fiapx.wecando.click\",
                \"Type\": \"A\",
                \"TTL\": 300,
                \"ResourceRecords\": [{
                    \"Value\": \"$WORKER_IP\"
                }]
            }
        }]
    }"

echo "✅ DNS configurado com sucesso!"

# Verificar se o cert-manager está funcionando
echo "🔒 Verificando cert-manager..."
if ! kubectl get pods -n cert-manager &> /dev/null; then
    echo "❌ cert-manager não encontrado. Instalando..."
    
    # Instalar cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    # Aguardar cert-manager estar pronto
    echo "⏳ Aguardando cert-manager..."
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
fi

echo "✅ cert-manager está funcionando"

# Aplicar configuração do Ingress
echo "🔧 Aplicando configuração do Ingress..."
kubectl apply -f infrastructure/ingress/ingress-https.yaml

# Verificar status do certificado
echo "📋 Verificando certificado..."
kubectl get certificates -n fiapx

echo "🎉 Configuração concluída!"
echo ""
echo "🌐 Acesse: https://fiapx.wecando.click"
echo "📊 Verifique os certificados com: kubectl get certificates -n fiapx"
echo "🔍 Logs do cert-manager: kubectl logs -n cert-manager deployment/cert-manager"
echo ""
echo "⏰ Aguarde alguns minutos para a propagação do DNS e emissão do certificado"
