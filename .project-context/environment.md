# Ambiente e Credenciais do Projeto FIAP-X

## Servidor Kubernetes (AWS)
- **Host**: worker.wecando.click
- **Usuário**: ubuntu
- **Chave SSH**: ~/.ssh/keyPrincipal.pem
- **Comando de conexão**: `ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click`

## Docker Hub
- **Usuário**: hmoraes
- **Senha**: Ch@plinh45
- **Login**: `echo "Ch@plinh45" | docker login -u hmoraes --password-stdin`

## Estrutura do Projeto no Servidor
```
~/frontend/                    # Frontend com arquivos fonte
~/k8s-manifests/              # Manifests Kubernetes atualizados
~/projeto-fiapx-arm64/        # Projeto original ARM64
~/infrastructure/             # Infraestrutura K8s
```

## Comandos Padrão de Deploy
```bash
# Build e Push de imagem (no servidor AWS)
cd frontend && docker build -t hmoraes/fiapx-frontend:vX.X .
docker push hmoraes/fiapx-frontend:vX.X

# Deploy Kubernetes
kubectl apply -f ~/k8s-manifests/[service].yaml
kubectl rollout restart deployment/[service]-deployment -n fiapx
kubectl rollout status deployment/[service]-deployment -n fiapx
```

## URLs dos Serviços
- **Frontend NodePort**: http://worker.wecando.click:30080
- **Frontend Amplify**: https://main.d13ms2nooclzwx.amplifyapp.com
- **API Ingress**: https://api.wecando.click
- **Microsserviços via Ingress**:
  - Auth: http://api.wecando.click/auth
  - Upload: http://api.wecando.click/upload  
  - Processing: http://api.wecando.click/processing
  - Storage: http://api.wecando.click/storage
