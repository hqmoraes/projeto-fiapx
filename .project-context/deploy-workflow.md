# Workflow de Deploy - Projeto FIAP-X

## Pré-requisitos
Sempre execute estes comandos antes de qualquer deploy:

```bash
# 1. Login no Docker Hub (no servidor AWS)
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "echo 'Ch@plinh45' | docker login -u hmoraes --password-stdin"

# 2. Verificar se estou logado
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "docker info | grep Username"
```

## Deploy de Frontend
```bash
# 1. Copiar arquivos corrigidos (do local para servidor)
scp -i ~/.ssh/keyPrincipal.pem config.js api.js app.js ubuntu@worker.wecando.click:~/frontend/

# 2. Build da imagem ARM64 (no servidor)
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "cd frontend && docker build -t hmoraes/fiapx-frontend:vX.X ."

# 3. Push para Docker Hub (no servidor)
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "docker push hmoraes/fiapx-frontend:vX.X"

# 4. Atualizar YAML e copiar (local)
# Editar ../infrastructure/kubernetes/frontend/frontend.yaml -> image: hmoraes/fiapx-frontend:vX.X
scp -i ~/.ssh/keyPrincipal.pem ../infrastructure/kubernetes/frontend/frontend.yaml ubuntu@worker.wecando.click:~/k8s-manifests/

# 5. Deploy no Kubernetes (no servidor)
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl apply -f ~/k8s-manifests/frontend.yaml"
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl rollout restart deployment/frontend-deployment -n fiapx"
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl rollout status deployment/frontend-deployment -n fiapx"
```

## Deploy de Microsserviços (Go)
```bash
# 1. Copiar arquivos Go (exemplo: auth-service)
scp -i ~/.ssh/keyPrincipal.pem -r ../auth-service ubuntu@worker.wecando.click:~/

# 2. Build da imagem ARM64 
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "cd auth-service && docker build -t hmoraes/fiapx-auth-service:vX.X ."

# 3. Push e Deploy
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "docker push hmoraes/fiapx-auth-service:vX.X"
# Seguir mesmo padrão do frontend para K8s deploy
```

## Verificação Pós-Deploy
```bash
# Verificar pods
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl get pods -n fiapx"

# Verificar logs (últimas 20 linhas)
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "kubectl logs -n fiapx -l app=SERVICE_NAME --tail=20"

# Testar endpoints
curl -k https://api.wecando.click/SERVICE/health
```

## Troubleshooting Comum
```bash
# Pod não inicia
kubectl describe pod POD_NAME -n fiapx

# Imagem não encontrada  
docker images | grep fiapx

# Problemas de rede
kubectl get svc -n fiapx
kubectl get ingress -n fiapx
```
