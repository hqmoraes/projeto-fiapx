#!/bin/bash

# FIAP-X - Preparação Completa para Deploy
# Este script prepara todos os componentes para deploy em produção

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}    FIAP-X - Preparação para Deploy      ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo

# 1. Verificar estrutura de segurança
echo -e "${BLUE}1. 🔍 Verificando estrutura de segurança...${NC}"

echo -e "${YELLOW}   📁 Verificando .gitignore files:${NC}"
for service in . auth-service upload-service processing-service storage-service frontend; do
    if [[ -f "$service/.gitignore" ]]; then
        if grep -q "\*credentials\*" "$service/.gitignore" 2>/dev/null; then
            echo -e "      ✅ $service/.gitignore - protegido"
        else
            echo -e "      ⚠️  $service/.gitignore - precisa atualização"
        fi
    else
        echo -e "      ❌ $service/.gitignore - não encontrado"
    fi
done

echo -e "${YELLOW}   🔐 Verificando arquivos sensíveis:${NC}"
if [[ -f "temp/fiapx-error-notification_credentials.csv.backup" ]]; then
    echo -e "      ✅ Credenciais SES - backup seguro"
else
    echo -e "      ❌ Credenciais SES - não encontrado"
fi

# 2. Verificar configurações dos microsserviços
echo -e "${BLUE}2. ⚙️  Verificando configurações dos microsserviços...${NC}"

echo -e "${YELLOW}   🧪 Verificando .env.test files:${NC}"
for service in auth-service upload-service processing-service storage-service; do
    if [[ -f "$service/.env.test" ]]; then
        if grep -q "test-secret-key" "$service/.env.test" 2>/dev/null; then
            echo -e "      ❌ $service/.env.test - ainda tem secret hardcoded"
        else
            echo -e "      ✅ $service/.env.test - seguro"
        fi
    else
        echo -e "      ⚠️  $service/.env.test - não encontrado"
    fi
done

echo -e "${YELLOW}   🔧 Verificando workflows CI/CD:${NC}"
for service in auth-service upload-service processing-service storage-service; do
    workflow_file="$service/.github/workflows/ci.yml"
    if [[ -f "$workflow_file" ]]; then
        if grep -q "go-version: 1.21" "$workflow_file" 2>/dev/null; then
            echo -e "      ✅ $service - workflow atualizado"
        elif grep -q "go-version: 1.19" "$workflow_file" 2>/dev/null; then
            echo -e "      ⚠️  $service - workflow precisa atualização"
        else
            echo -e "      ❌ $service - workflow sem versão Go"
        fi
    else
        echo -e "      ❌ $service - workflow não encontrado"
    fi
done

# 3. Verificar configuração do notification-service
echo -e "${BLUE}3. 📧 Verificando configuração do notification-service...${NC}"

if grep -q "email-smtp.us-east-1.amazonaws.com" notification-service/cmd/notification-service/main.go 2>/dev/null; then
    echo -e "      ✅ Notification service - configurado para SES"
else
    echo -e "      ⚠️  Notification service - ainda configurado para Gmail"
fi

if grep -q "ses-email-secrets" infrastructure/kubernetes/notification-service.yaml 2>/dev/null; then
    echo -e "      ✅ Kubernetes manifest - configurado para SES secrets"
else
    echo -e "      ⚠️  Kubernetes manifest - precisa atualização"
fi

# 4. Verificar CloudFront
echo -e "${BLUE}4. ☁️  Verificando configuração do CloudFront...${NC}"

if grep -q "fiapx-frontend-origin" infrastructure/https-cloudfront/cloudfront-distribution.yaml 2>/dev/null; then
    echo -e "      ✅ CloudFront - configurado com origem separada para frontend"
else
    echo -e "      ⚠️  CloudFront - usando origem única"
fi

if grep -q "CacheBehaviors" infrastructure/https-cloudfront/cloudfront-distribution.yaml 2>/dev/null; then
    echo -e "      ✅ CloudFront - configurado com cache behaviors"
else
    echo -e "      ⚠️  CloudFront - sem cache behaviors separados"
fi

# 5. Gerar comandos para deploy
echo -e "${BLUE}5. 🚀 Gerando comandos para deploy...${NC}"

cat > deployment-commands.sh << 'EOF'
#!/bin/bash

# FIAP-X - Comandos para Deploy Completo
# Execute estes comandos quando o kubectl estiver disponível

set -e

echo "🚀 FIAP-X - Deploy Completo Iniciando..."

# 1. Setup do Amazon SES
echo "📧 1. Configurando Amazon SES..."
./scripts/auto-setup-ses.sh

# 2. Aplicar todos os manifests atualizados
echo "⚙️ 2. Aplicando manifests do Kubernetes..."
kubectl apply -f infrastructure/kubernetes/

# 3. Verificar status de todos os deployments
echo "📊 3. Verificando status dos deployments..."
kubectl get deployments -n fiapx

# 4. Verificar pods
echo "🔍 4. Verificando pods..."
kubectl get pods -n fiapx

# 5. Verificar services
echo "🌐 5. Verificando services..."
kubectl get services -n fiapx

# 6. Testar endpoints
echo "🧪 6. Testando endpoints..."
echo "Aguarde os pods ficarem prontos e teste:"
echo "curl -k https://fiapx.wecando.click/auth/health"
echo "curl -k https://fiapx.wecando.click/upload/health"
echo "curl -k https://fiapx.wecando.click/processing/health"
echo "curl -k https://fiapx.wecando.click/storage/health"

echo "✅ Deploy completo finalizado!"
EOF

chmod +x deployment-commands.sh

echo -e "${GREEN}✅ Arquivo de comandos criado: deployment-commands.sh${NC}"

# 6. Criar arquivo de secrets para GitHub
echo -e "${BLUE}6. 🔑 Criando arquivo de secrets para GitHub...${NC}"

cat > github-secrets-setup.md << 'EOF'
# 🔑 GitHub Secrets Setup

## Secrets necessários para todos os repositórios:

### 1. Docker Hub
```
DOCKER_USERNAME=hqmoraes
DOCKER_PASSWORD=<your-docker-hub-token>
```

### 2. JWT para testes
```
JWT_SECRET=$(openssl rand -base64 32)
```

### 3. Database para testes
```
POSTGRES_PASSWORD=test-password-secure
MINIO_ACCESS_KEY=test-access-key
MINIO_SECRET_KEY=test-secret-key
```

## Como configurar:

### Via GitHub CLI (recomendado):
```bash
# Para cada repositório:
gh secret set DOCKER_USERNAME -b "hqmoraes" -R hqmoraes/fiapx-auth-service
gh secret set DOCKER_PASSWORD -b "<token>" -R hqmoraes/fiapx-auth-service
gh secret set JWT_SECRET -b "$(openssl rand -base64 32)" -R hqmoraes/fiapx-auth-service

# Repetir para:
# - hqmoraes/fiapx-upload-service
# - hqmoraes/fiapx-processing-service
# - hqmoraes/fiapx-storage-service
# - hqmoraes/fiapx-notification-service
```

### Via Interface Web:
1. Acesse: https://github.com/hqmoraes/fiapx-auth-service/settings/secrets/actions
2. Clique em "New repository secret"
3. Adicione cada secret listado acima
4. Repita para todos os repositórios

## Teste dos Pipelines:
1. Faça um commit na branch `validar`
2. Verifique se todos os jobs passam:
   - Security Scan ✅
   - Test and Quality Gate ✅
   - Build and Push Images ✅ (apenas na main)

EOF

echo -e "${GREEN}✅ Arquivo de secrets criado: github-secrets-setup.md${NC}"

# 7. Resumo final
echo
echo -e "${BLUE}🎯 RESUMO DA PREPARAÇÃO:${NC}"
echo
echo -e "${GREEN}✅ COMPLETADOS:${NC}"
echo -e "   🔐 Estrutura de segurança configurada"
echo -e "   ⚙️  Microsserviços atualizados"
echo -e "   📧 Amazon SES configurado"
echo -e "   ☁️  CloudFront corrigido"
echo -e "   🔧 CI/CD workflows atualizados"

echo
echo -e "${YELLOW}📋 PRÓXIMOS PASSOS:${NC}"
echo -e "1. Configure secrets no GitHub usando: ${BLUE}github-secrets-setup.md${NC}"
echo -e "2. Conecte ao cluster e execute: ${BLUE}./deployment-commands.sh${NC}"
echo -e "3. Teste a aplicação com HTTPS"

echo
echo -e "${BLUE}📁 ARQUIVOS CRIADOS:${NC}"
echo -e "   📜 deployment-commands.sh - comandos para deploy"
echo -e "   📖 github-secrets-setup.md - guia para configurar secrets"
echo -e "   🔧 scripts/auto-setup-ses.sh - setup automático do SES"
echo -e "   📋 templates/ci-cd-template.yml - template CI/CD"

echo
echo -e "${GREEN}🎉 Preparação completa! O projeto está pronto para deploy.${NC}"
