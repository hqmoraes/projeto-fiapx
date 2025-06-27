#!/bin/bash

# Script para configurar DNS no Route53 para o domínio wecando.click
# FIAP X - Solução HTTPS com cert-manager

set -e

echo "🌐 Configurando DNS no Route53 para wecando.click"

# Obter o IP público do cluster
CLUSTER_IP=$(curl -s http://checkip.amazonaws.com)
echo "📍 IP público do cluster: $CLUSTER_IP"

# Obter a Hosted Zone ID do domínio wecando.click
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='wecando.click.'].Id" --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "❌ Hosted Zone para wecando.click não encontrada!"
    echo "🔧 Criando Hosted Zone..."
    
    HOSTED_ZONE_ID=$(aws route53 create-hosted-zone \
        --name wecando.click \
        --caller-reference $(date +%s) \
        --query "HostedZone.Id" \
        --output text | cut -d'/' -f3)
    
    echo "✅ Hosted Zone criada: $HOSTED_ZONE_ID"
else
    echo "✅ Hosted Zone encontrada: $HOSTED_ZONE_ID"
fi

# Criar registro A para api.wecando.click
echo "📝 Criando registro A para api.wecando.click → $CLUSTER_IP"

cat > /tmp/dns-record.json << EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "api.wecando.click",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$CLUSTER_IP"
                    }
                ]
            }
        }
    ]
}
EOF

# Aplicar mudança no Route53
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file:///tmp/dns-record.json \
    --query "ChangeInfo.Id" \
    --output text)

echo "🔄 Mudança DNS criada: $CHANGE_ID"

# Aguardar propagação
echo "⏳ Aguardando propagação DNS..."
aws route53 wait resource-record-sets-changed --id $CHANGE_ID

echo "✅ DNS configurado com sucesso!"
echo ""
echo "🌐 Configurações DNS:"
echo "   Domínio: api.wecando.click"
echo "   IP: $CLUSTER_IP"
echo "   Hosted Zone: $HOSTED_ZONE_ID"
echo ""
echo "🧪 Teste DNS:"
echo "   nslookup api.wecando.click"
echo "   dig api.wecando.click"

# Cleanup
rm -f /tmp/dns-record.json

echo ""
echo "🎯 Próximos passos:"
echo "1. Instalar nginx-ingress no cluster"
echo "2. Instalar cert-manager"
echo "3. Aplicar manifests do ingress"
echo "4. Aguardar certificado Let's Encrypt"
