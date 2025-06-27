#!/bin/bash

# Script para configurar proxy HTTPS para os microsserviços
# FIAP X - Solução para Mixed Content

set -e

echo "🔧 Configurando proxy HTTPS para microsserviços..."

# Verificar se nginx está instalado
if ! command -v nginx &> /dev/null; then
    echo "📦 Instalando nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

# Verificar se certbot está instalado
if ! command -v certbot &> /dev/null; then
    echo "📦 Instalando certbot..."
    sudo apt install -y certbot python3-certbot-nginx
fi

echo "🔑 Configurando certificado SSL..."

# Criar configuração nginx para proxy
sudo tee /etc/nginx/sites-available/fiapx-proxy > /dev/null <<EOF
# FIAP X - Proxy HTTPS para microsserviços
server {
    listen 80;
    server_name api.fiapx.com;
    
    # Redirect to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.fiapx.com;
    
    # SSL Configuration (será configurado pelo certbot)
    
    # CORS Headers
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, Origin, User-Agent, DNT, Cache-Control, X-Mx-ReqToken, Keep-Alive, X-Requested-With, If-Modified-Since' always;
    
    # Handle preflight requests
    location / {
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, Origin, User-Agent, DNT, Cache-Control, X-Mx-ReqToken, Keep-Alive, X-Requested-With, If-Modified-Since' always;
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
    
    # Auth Service Proxy
    location /auth/ {
        proxy_pass http://127.0.0.1:31404/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Upload Service Proxy
    location /upload/ {
        proxy_pass http://127.0.0.1:32159/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }
    
    # Processing Service Proxy
    location /processing/ {
        proxy_pass http://127.0.0.1:32382/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Storage Service Proxy
    location /storage/ {
        proxy_pass http://127.0.0.1:31627/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Habilitar site
sudo ln -sf /etc/nginx/sites-available/fiapx-proxy /etc/nginx/sites-enabled/

# Testar configuração nginx
sudo nginx -t

echo "✅ Nginx configurado! Agora você precisa:"
echo "1. Configurar um domínio (api.fiapx.com) apontando para seu servidor"
echo "2. Executar: sudo certbot --nginx -d api.fiapx.com"
echo "3. Atualizar config.js com as URLs HTTPS"
