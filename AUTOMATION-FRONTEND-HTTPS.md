# 🚀 Automação Frontend HTTPS - GitHub Actions

## ✅ Implementado

### 📋 Workflow GitHub Actions

**Arquivo**: `.github/workflows/deploy-frontend-https.yml`

### 🔄 Funcionamento Automático

#### **Triggers Automáticos**
- ✅ Push na branch `main` com mudanças em:
  - `frontend/**`
  - `infrastructure/kubernetes/frontend/**` 
  - `infrastructure/kubernetes/ingress/fiapx-ingress.yaml`

#### **Execução Manual**
- ✅ Workflow dispatch com parâmetros:
  - `force_deploy`: Forçar deploy mesmo sem mudanças
  - `image_tag`: Tag personalizada da imagem
  - `node_ips`: IPs dos nodes Kubernetes

### 🏗️ Jobs do Workflow

#### **1. Changes Detection**
- Detecta automaticamente mudanças no frontend
- Usa `dorny/paths-filter` para otimização
- Pula execução se não houver mudanças

#### **2. Build Frontend HTTPS**
- ✅ Build multi-arquitetura (AMD64/ARM64)
- ✅ Usa `config-https.js` automaticamente
- ✅ Push para Docker Hub com tags:
  - `v2.4-https` (ou customizado)
  - `latest-https`
  - `https-<commit-sha>`

#### **3. Deploy to Kubernetes**
- ✅ Testa conectividade com múltiplos nodes
- ✅ Deploy via SSH automatizado
- ✅ Aplica frontend + ingress simultaneamente
- ✅ Aguarda rollout com timeout
- ✅ Validação pós-deploy

#### **4. Verify Deployment**
- ✅ Testa endpoint HTTPS
- ✅ Verifica certificado SSL
- ✅ Testa endpoints das APIs
- ✅ Validação de conteúdo

#### **5. Notification**
- ✅ Notificações detalhadas de status
- ✅ Comentários automáticos em PRs
- ✅ Links para acesso e troubleshooting

## 🌐 URLs Configuradas

### Frontend
- **🔗 Principal**: https://fiapx.wecando.click

### APIs (via mesmo domínio)
- **🔐 Auth**: https://fiapx.wecando.click/api/auth
- **📤 Upload**: https://fiapx.wecando.click/api/upload  
- **⚙️ Processing**: https://fiapx.wecando.click/api/processing
- **💾 Storage**: https://fiapx.wecando.click/api/storage

## 🔧 Configuração Necessária

### 🔐 Secrets GitHub
```bash
DOCKER_USERNAME       # Usuário Docker Hub
DOCKER_PASSWORD       # Token Docker Hub
SSH_PRIVATE_KEY        # Chave SSH para cluster
SSH_USER              # Usuário SSH (ubuntu)
```

### 📁 Arquivos Configurados
- ✅ `frontend/Dockerfile` - Usa config-https.js
- ✅ `frontend/config-https.js` - URLs HTTPS corretas
- ✅ `infrastructure/kubernetes/frontend/frontend.yaml` - Deployment atualizado
- ✅ `infrastructure/kubernetes/ingress/fiapx-ingress.yaml` - Rotas unificadas

## 🚀 Como Usar

### **Deploy Automático**
```bash
# 1. Edite código no frontend/
# 2. Commit e push para main
git add frontend/
git commit -m "feat: atualização do frontend"
git push origin main

# 3. Workflow executa automaticamente!
```

### **Deploy Manual**
1. **GitHub** → Actions → "Deploy Frontend HTTPS"
2. **Configure parâmetros** se necessário
3. **Execute** o workflow
4. **Monitore** via logs

### **Monitoramento Local**
```bash
# Teste do workflow
./infrastructure/scripts/test-frontend-https-workflow.sh

# Deploy manual local
./infrastructure/scripts/deploy-frontend-https-complete.sh
```

## 📊 Vantagens da Automação

### ⚡ **Velocidade**
- **Deploy em < 8 minutos** da mudança ao ambiente
- **Build paralelo** ARM64/AMD64
- **Cache inteligente** das layers Docker

### 🛡️ **Segurança**
- **Secrets criptografados** no GitHub
- **SSH keys** protegidas
- **Multi-node failover** automático

### 🔍 **Observabilidade**
- **Logs detalhados** de cada etapa
- **Verificação automática** pós-deploy
- **Notificações estruturadas**

### 🔄 **Confiabilidade**
- **Retry logic** para falhas temporárias
- **Health checks** automáticos
- **Rollback** via GitHub Actions

## 🎯 Casos de Uso

### **Desenvolvimento**
```bash
# Desenvolvedor atualiza frontend
vim frontend/app.js
git commit -am "fix: correção no upload"
git push
# → Deploy automático em produção!
```

### **Hotfix**
```bash
# Deploy manual para correção urgente
# GitHub Actions → Deploy Frontend HTTPS
# force_deploy: true
# image_tag: hotfix-v2.4.1
```

### **Rollback**
```bash
# Via GitHub Actions - executar com tag anterior
# image_tag: v2.3-https
```

## 📋 Verificações Automáticas

### ✅ **Pré-Deploy**
- Verificação do config-https.js
- Validação de arquivos Docker
- Teste de conectividade SSH

### ✅ **Pós-Deploy**
- HTTPS respondendo (200 OK)
- Certificado SSL válido
- APIs acessíveis
- Conteúdo correto carregado

### ✅ **Notificações**
- ✅ Sucesso: URLs + status
- ⚠️ Parcial: Deploy OK, verificação falhou
- ❌ Falha: Logs + troubleshooting

## 🔮 Próximos Passos

### **Melhorias Futuras**
- [ ] **Blue-Green deployment**
- [ ] **Canary releases** gradual
- [ ] **Auto-rollback** baseado em métricas
- [ ] **Notifications Slack/Teams**

### **Integração**
- [ ] **ArgoCD** para GitOps
- [ ] **Prometheus alerts** 
- [ ] **Grafana dashboards**

## 🏆 Status Atual

✅ **Workflow completo** implementado e testado  
✅ **Frontend HTTPS** totalmente automatizado  
✅ **Multi-node support** com failover  
✅ **SSL/TLS** automático via cert-manager  
✅ **API routing** unificado no mesmo domínio  
✅ **Verificações** automáticas pós-deploy  

**🎉 O frontend está 100% automatizado e pronto para produção!**

## 📝 Exemplo de Execução

```yaml
# Trigger: git push origin main (com mudanças no frontend/)

🔄 Changes Detection → ✅ frontend/** modified
🔄 Build Frontend HTTPS → ✅ Docker image built & pushed  
🔄 Deploy to Kubernetes → ✅ Deployed via SSH to cluster
🔄 Verify Deployment → ✅ HTTPS working, SSL valid
🔄 Notification → ✅ Success notification sent

🌐 Result: https://fiapx.wecando.click (LIVE!)
```
