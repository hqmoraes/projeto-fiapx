# 🔍 VERIFICAÇÃO DE SECRETS E WORKFLOW - GUIA COMPLETO

## 📋 CHECKLIST PRÉ-DEPLOY

Antes de fazer qualquer deploy em produção, verifique:

### 1. 🔐 Secrets Configuradas
```bash
./check-github-secrets.sh
```

| Secret | Status | Objetivo |
|--------|--------|----------|
| DOCKER_USERNAME | ✅ | Autenticação no Docker Hub (hmoraes) |
| DOCKERHUB_USERNAME | ✅ | Alternativa para autenticação (manter consistência) |
| DOCKER_PASSWORD | ✅ | Token de acesso ao Docker Hub |
| DOCKERHUB_TOKEN | ✅ | Alternativa para token (manter consistência) |
| KUBE_CONFIG | ✅ | Acesso ao cluster Kubernetes |
| SSH_PRIVATE_KEY | ✅ | Acesso SSH ao servidor |
| SSH_USER | ✅ | Usuário SSH (ubuntu, ec2-user) |
| K8S_HOST | ✅ | Endereço do servidor Kubernetes |
| AWS_ACCESS_KEY_ID | ✅ | Acesso programático à AWS |
| AWS_SECRET_ACCESS_KEY | ✅ | Chave secreta para AWS |
| JWT_SECRET | ✅ | Secret para autenticação JWT |

### 2. 🛠️ Workflows Padronizados
```bash
./fix-workflows.sh
```

| Workflow | Status | Serviço |
|----------|--------|---------|
| production-cicd.yml | ✅ | Pipeline principal |
| ci-cd.yml | ✅ | Testes e quality gates |
| deploy-fiapx-https.yml | ✅ | Configuração HTTPS |
| deploy-notification-service.yml | ✅ | Serviço de notificação |
| deploy-frontend-https.yml | ✅ | Frontend com HTTPS |

### 3. 🔒 Proteção de Branches
Verificar manualmente:
- `main` (produção)
- `validar` (staging)

Regras recomendadas:
- Require pull request reviews
- Dismiss stale pull request approvals
- Require status checks to pass
- Require signed commits
- Include administrators

## 🚦 WORKFLOW EXECUTÁVEIS

### 1. Validar CI/CD Básico
```bash
git checkout -b test-ci-cd
touch test-file.txt
git add test-file.txt
git commit -m "test: validate CI/CD pipeline"
git push origin test-ci-cd
```

### 2. Validar Deployment em Staging
```bash
git checkout validar
git merge test-ci-cd
git push origin validar
```

### 3. Simular Deploy em Produção
```bash
# Crie um PR de validar para main
# Aguarde todos os checks passarem
# Aprove o PR e faça merge
```

## 🔍 VALIDAÇÃO PÓS-DEPLOY

### 1. Verificar Logs
```bash
# Ver logs dos containers
kubectl logs -n fiapx-production -l app=auth-service --tail=100

# Ver eventos do Kubernetes
kubectl get events -n fiapx-production --sort-by='.lastTimestamp'
```

### 2. Health Checks
```bash
# Health check do serviço de autenticação
curl -f https://fiapx.wecando.click/auth/health

# Health check do frontend
curl -f https://fiapx.wecando.click/
```

### 3. Validação de Credenciais
```bash
# Testar geração de JWT
curl -X POST https://fiapx.wecando.click/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'
```

## 🔄 PROCESSO DE ROLLBACK

Em caso de falha no deploy:

### 1. Rollback Automático (configurado no workflow)
O pipeline tentará automaticamente fazer rollback se o health check falhar.

### 2. Rollback Manual
```bash
# Reverter para a versão anterior
kubectl rollout undo deployment/auth-service -n fiapx-production

# Verificar status do rollback
kubectl rollout status deployment/auth-service -n fiapx-production
```

### 3. Reverter código no GitHub
```bash
# Reverter o último merge
git revert -m 1 HEAD
git push origin main
```

## 📞 CONTATOS PARA SUPORTE

| Tipo de Problema | Contato | Email |
|------------------|---------|-------|
| CI/CD Pipeline | DevOps Team | devops@fiapx.com |
| Kubernetes | Platform Team | platform@fiapx.com |
| Aplicação | Dev Team | dev@fiapx.com |
| Segurança | Security Team | security@fiapx.com |

## 📊 MÉTRICAS DE SUCESSO

- **Tempo de deploy**: < 10 minutos
- **Taxa de falha de build**: < 5%
- **Cobertura de testes**: > 80%
- **Tempo médio de recuperação**: < 30 minutos

---

> 🔔 **LEMBRETE**: Sempre execute o script `check-github-secrets.sh` antes de qualquer alteração importante no repositório ou workflows.
