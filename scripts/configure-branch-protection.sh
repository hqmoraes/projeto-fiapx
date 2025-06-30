#!/bin/bash

# Script para configurar proteção de branches nos repositórios FIAP-X
# Requer GITHUB_TOKEN com permissões de admin nos repositórios

set -e

GITHUB_TOKEN="${GITHUB_TOKEN:-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}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN não definido"
    exit 1
fi

# Lista de repositórios
repos=(
    "hqmoraes/fiapx-auth-service"
    "hqmoraes/fiapx-upload-service"
    "hqmoraes/fiapx-processing-service"  
    "hqmoraes/fiapx-storage-service"
    "hqmoraes/fiapx-frontend"
)

# Configuração de proteção
protection_config='{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "bypass_pull_request_allowances": {
      "users": [],
      "teams": []
    }
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}'

echo "🔧 Configurando proteção de branches..."
echo "📋 Repositórios: ${#repos[@]}"
echo ""

for repo in "${repos[@]}"; do
    echo "⚙️  Configurando proteção para $repo..."
    
    # Configurar proteção da branch main
    response=$(curl -s -w "%{http_code}" -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$repo/branches/main/protection" \
        -d "$protection_config")
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo "✅ $repo - Proteção configurada com sucesso"
    elif [ "$http_code" = "422" ]; then
        echo "⚠️  $repo - Proteção já existe (HTTP $http_code)"
    else
        echo "❌ $repo - Erro ao configurar proteção (HTTP $http_code)"
    fi
    
    sleep 1
done

echo ""
echo "🎉 Configuração concluída!"
echo ""
echo "📖 Regras aplicadas:"
echo "   ✅ Pull Request obrigatório para merge na main"
echo "   ✅ Pelo menos 1 aprovação necessária"
echo "   ✅ Reviews antigas descartadas em novos commits"
echo "   ✅ Administradores também seguem as regras"
echo "   ✅ Force push bloqueado"
echo "   ✅ Deleção da branch bloqueada"
echo ""
echo "🔄 Fluxo de trabalho:"
echo "   1. Desenvolver na branch 'validar'"
echo "   2. Push para 'validar'"
echo "   3. Criar Pull Request: validar → main"
echo "   4. Workflow CI executa automaticamente"
echo "   5. Aprovação necessária antes do merge"
echo "   6. Merge para main → Deploy automático"
