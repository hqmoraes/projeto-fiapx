# 🔐 Scripts de Segurança - GitHub Secrets

## 📋 Scripts Disponíveis

### 🔍 `check-github-secrets.sh`
**Verifica quais secrets estão configuradas**
```bash
./check-github-secrets.sh
```
- Lista todas as secrets necessárias
- Indica quais estão configuradas ✅ ou faltando ❌
- Fornece comandos para configurar as faltantes

### 🚀 `setup-github-secrets.sh`
**Configuração interativa e rápida**
```bash
./setup-github-secrets.sh
```
- Configura todas as secrets de uma vez
- Interface interativa para inserir credenciais
- Validação automática dos valores

### 🚨 `security-cleanup.sh`
**Remove credenciais expostas**
```bash
./security-cleanup.sh
```
- Remove arquivos com credenciais expostas
- Cria templates seguros
- Atualiza .gitignore para prevenir futuras exposições

## ⚠️ CREDENCIAIS EXPOSTAS - AÇÃO URGENTE

**🚨 ENCONTRAMOS CREDENCIAIS REAIS NO REPOSITÓRIO!**

### Credenciais AWS SES expostas:
- Arquivo: `temp/fiapx-error-notification_credentials.csv.backup`
- Username: `AKIA2CEKWSP6M2BNI4BU`
- Password: `BO1zyE4MyRQiyqzpm/AJHYDmQ21qjLln0djML/HUWY63`

### 🚨 AÇÕES IMEDIATAS:

1. **Execute a limpeza:**
```bash
./security-cleanup.sh
```

2. **Revogue credenciais AWS:**
   - Acesse: https://console.aws.amazon.com/iam/home#/users/fiapx-error-notification
   - DELETE as credenciais expostas IMEDIATAMENTE

3. **Crie novas credenciais e configure via GitHub Secrets**

## 🛠️ Configuração Correta das Secrets

### Usuários Corretos:
- **GitHub**: `hqmoraes`
- **Docker Hub**: `hmoraes` (diferente do GitHub!)

### Secrets Necessárias:
```bash
# Docker Hub (4 secrets - nomes inconsistentes nos workflows)
DOCKER_USERNAME=hmoraes
DOCKERHUB_USERNAME=hmoraes  
DOCKER_PASSWORD=dckr_pat_xxxxx
DOCKERHUB_TOKEN=dckr_pat_xxxxx

# Kubernetes
KUBE_CONFIG=<base64-kubeconfig>

# SSH
SSH_PRIVATE_KEY=<ssh-private-key>
SSH_USER=ubuntu
K8S_HOST=<server-ip>

# AWS
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# Application
JWT_SECRET=<base64-secret>
```

## 🔄 Workflow Sugerido

### Para Configuração Inicial:
```bash
# 1. Verificar estado atual
./check-github-secrets.sh

# 2. Configurar secrets (se necessário)
./setup-github-secrets.sh

# 3. Verificar novamente
./check-github-secrets.sh
```

### Para Correção de Segurança:
```bash
# 1. Limpar credenciais expostas
./security-cleanup.sh

# 2. Revogar credenciais no AWS Console

# 3. Configurar novas credenciais
./setup-github-secrets.sh

# 4. Commitar mudanças
git add .
git commit -m "security: fix exposed credentials"
git push
```

## 📚 Documentação Adicional

- `GITHUB-SECRETS-COMPLETE-SETUP.md` - Guia completo
- `SECURITY-ALERT-EXPOSED-CREDENTIALS.md` - Alerta de segurança
- `.gitignore` - Atualizado com padrões de arquivos sensíveis

## 🎯 Teste Final

Após configurar tudo:
1. Faça um commit de teste
2. Verifique workflows: https://github.com/hqmoraes/projeto-fiapx/actions
3. Confirme que todos os jobs passam:
   - ✅ Test and Quality Gate
   - ✅ Security Scan
   - ✅ Build and Push Docker Images
   - ✅ Deploy to Kubernetes

---

> **⚠️ CRÍTICO:** Mantenha essas credenciais seguras e nunca as exponha em logs ou commits!
