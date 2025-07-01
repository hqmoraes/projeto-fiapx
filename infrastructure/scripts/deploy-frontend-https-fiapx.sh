#!/bin/bash

# Script para deploy do frontend com configuração HTTPS
# Atualiza o frontend para usar https://fiapx.wecando.click

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "🚀 FIAP-X: Deploy Frontend HTTPS"
echo "================================"

# Configurações
SSH_KEY="~/.ssh/keyPrincipal.pem"
SSH_USER="ubuntu"
SSH_HOST="worker.wecando.click"
FRONTEND_IMAGE="hmoraes/fiapx-frontend:v2.4-https"

# Função para executar comandos via SSH
run_ssh() {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$SSH_HOST "$1"
}

# Verificar se está no diretório correto
if [ ! -f "frontend/index.html" ]; then
    echo "❌ Execute este script do diretório raiz do projeto"
    exit 1
fi

cd frontend/

log "📝 Criando configuração HTTPS para produção..."

# Backup da configuração atual
cp config.js config.js.backup

# Aplicar configuração HTTPS
cp config-https.js config.js

log "✅ Configuração HTTPS aplicada"

# Verificar configuração
log "🔍 Verificando configuração HTTPS..."
if grep -q "https://api.wecando.click" config.js; then
    log "✅ URLs HTTPS configuradas corretamente"
else
    warn "⚠️ Configuração HTTPS não detectada"
    exit 1
fi

log "🐳 Criando nova imagem Docker..."

# Criar Dockerfile temporário se não existir
if [ ! -f "Dockerfile" ]; then
    cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Copiar arquivos do frontend
COPY . /usr/share/nginx/html/

# Configuração do nginx
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    # Health check endpoint \
    location /health { \
        access_log off; \
        return 200 "OK\n"; \
        add_header Content-Type text/plain; \
    } \
    \
    # SPA fallback \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # Security headers \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    add_header X-Content-Type-Options "nosniff" always; \
    add_header X-XSS-Protection "1; mode=block" always; \
    add_header Referrer-Policy "strict-origin-when-cross-origin" always; \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
fi

# Build da imagem
log "🔨 Building Docker image..."
docker build -t $FRONTEND_IMAGE .

# Push da imagem
log "📤 Fazendo push da imagem..."
docker push $FRONTEND_IMAGE

log "✅ Imagem criada e enviada: $FRONTEND_IMAGE"

# Atualizar deployment no Kubernetes via SSH
log "🚀 Atualizando deployment no Kubernetes..."

# Criar deployment atualizado
cat > /tmp/frontend-https-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deployment
  namespace: fiapx
  labels:
    app: frontend
    version: v2.4-https
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        version: v2.4-https
      annotations:
        deployment/revision: "$(date +%s)"
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: frontend
              topologyKey: kubernetes.io/hostname
      containers:
      - name: frontend
        image: $FRONTEND_IMAGE
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        env:
        - name: NGINX_HOST
          value: "fiapx.wecando.click"
        - name: NGINX_PORT
          value: "80"
        - name: FRONTEND_VERSION
          value: "v2.4-https"
      restartPolicy: Always
EOF

# Copiar para o servidor e aplicar
scp -i $SSH_KEY -o StrictHostKeyChecking=no /tmp/frontend-https-deployment.yaml $SSH_USER@$SSH_HOST:/tmp/

run_ssh "kubectl apply -f /tmp/frontend-https-deployment.yaml"

log "⏳ Aguardando rollout do deployment..."
run_ssh "kubectl rollout status deployment/frontend-deployment -n fiapx --timeout=300s"

# Verificar status
log "📊 Status do deployment:"
run_ssh "kubectl get pods -l app=frontend -n fiapx"

# Verificar serviços
log "🌐 Status dos serviços:"
run_ssh "kubectl get services -l app=frontend -n fiapx"

# Testar endpoints
log "🧪 Testando frontend..."

# Aguardar alguns segundos para o serviço estar pronto
sleep 10

# Teste via curl
if curl -k -I "https://fiapx.wecando.click" 2>/dev/null | grep -q "200\|301\|302"; then
    log "✅ Frontend acessível via HTTPS: https://fiapx.wecando.click"
else
    warn "⚠️ Frontend ainda propagando. Teste em alguns minutos."
fi

# Cleanup
rm -f /tmp/frontend-https-deployment.yaml
rm -f Dockerfile

# Restaurar configuração original para desenvolvimento local
cp config.js.backup config.js

log "📋 Informações do deploy:"
log "   🌐 Frontend URL: https://fiapx.wecando.click"
log "   🐳 Imagem: $FRONTEND_IMAGE"
log "   📦 Deployment: frontend-deployment"
log "   🔧 API URLs: https://api.wecando.click/*"

echo ""
log "🎉 Deploy do frontend HTTPS concluído com sucesso!"
echo ""
log "📝 Próximos passos:"
log "1. Aguardar propagação DNS (alguns minutos)"
log "2. Acessar https://fiapx.wecando.click"
log "3. Testar funcionalidades (login, upload, processamento)"
log "4. Verificar se não há erros de Mixed Content"

echo ""
log "✅ FIAP-X Frontend HTTPS deploy completo!"
