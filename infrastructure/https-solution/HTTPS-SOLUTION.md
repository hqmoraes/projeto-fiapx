# 🔒 SOLUÇÃO HTTPS PARA MICROSSERVIÇOS FIAP X

## 🎯 Objetivo
Resolver o problema de **Mixed Content** entre frontend HTTPS (Amplify) e microsserviços HTTP (Kubernetes) usando recursos 100% AWS com arquitetura ARM64.

## 🏗️ Arquitetura da Solução

```
┌─────────────────────────────┐    HTTPS/TLS    ┌─────────────────────────────┐
│        AWS AMPLIFY          │ ◄────────────► │     KUBERNETES ARM64        │
│   Frontend (HTTPS)          │                │   Microsserviços (HTTPS)    │
├─────────────────────────────┤                ├─────────────────────────────┤
│ https://main.d13ms...       │                │ https://auth.wecando.click  │
│                             │                │ https://upload.wecando.click│
│ ✅ SSL/TLS automático       │                │ https://processing.wecando  │
│ ✅ CDN global              │                │ https://storage.wecando     │
└─────────────────────────────┘                └─────────────────────────────┘
                                                              ▲
                                                              │
                                                ┌─────────────────────────────┐
                                                │        COMPONENTES          │
                                                ├─────────────────────────────┤
                                                │ 🔑 cert-manager (ARM64)     │
                                                │ 🌐 nginx-ingress (ARM64)    │
                                                │ 🗺️ Route53 DNS              │
                                                │ 🔒 Let's Encrypt SSL        │
                                                └─────────────────────────────┘
```

## 🚀 Componentes da Solução

### 1. **cert-manager (ARM64)**
- **Função**: Geração automática de certificados SSL
- **Provedor**: Let's Encrypt (gratuito)
- **Renovação**: Automática (60 dias)

### 2. **nginx-ingress (ARM64)**
- **Função**: Proxy reverso HTTPS → HTTP
- **CORS**: Configurado para frontend Amplify
- **SSL Termination**: Termina SSL e encaminha HTTP interno

### 3. **Route53 DNS**
- **Domínio**: wecando.click
- **Subdomínios**:
  - `auth.wecando.click` → auth-service
  - `upload.wecando.click` → upload-service
  - `processing.wecando.click` → processing-service
  - `storage.wecando.click` → storage-service

### 4. **Ingress Rules**
- **SSL Redirect**: Força HTTPS
- **CORS Headers**: Permite requests do Amplify
- **Path Routing**: Encaminha para serviços corretos

## 📋 Pré-requisitos

### ✅ Verificações Necessárias
- [ ] Domínio `wecando.click` configurado no Route53
- [ ] Acesso SSH ao cluster: `worker.wecando.click`
- [ ] Chave SSH: `~/.ssh/keyPrincipal.pem`
- [ ] Cluster Kubernetes ARM64 operacional
- [ ] Microsserviços deployados e funcionais

### 🔧 Dependências
- AWS CLI configurado
- kubectl configurado
- SSH access ao cluster
- Permissões Route53

## 🚀 Deploy da Solução

### Passo 1: Configurar HTTPS no Cluster
```bash
chmod +x infrastructure/scripts/setup-https-cluster.sh
./infrastructure/scripts/setup-https-cluster.sh
```

**O que este script faz:**
1. 🔑 Instala cert-manager (ARM64)
2. 🌐 Instala nginx-ingress (ARM64) 
3. 🗺️ Configura DNS no Route53
4. 🔒 Cria certificados SSL Let's Encrypt
5. 🔗 Configura Ingress com HTTPS
6. ✅ Testa endpoints HTTPS

### Passo 2: Deploy Frontend Atualizado
```bash
chmod +x infrastructure/scripts/deploy-frontend-https.sh
./infrastructure/scripts/deploy-frontend-https.sh
```

**O que este script faz:**
1. 📝 Atualiza config.js com URLs HTTPS
2. 📦 Cria novo pacote do frontend
3. 🚀 Deploy no AWS Amplify
4. ✅ Testa integração HTTPS

## 🔍 Endpoints Finais

### 🌐 Frontend (AWS Amplify)
- **URL**: https://main.d13ms2nooclzwx.amplifyapp.com
- **Protocolo**: HTTPS (gerenciado pelo Amplify)

### 🛠️ Backend (Kubernetes + Ingress)
- **auth-service**: https://auth.wecando.click
- **upload-service**: https://upload.wecando.click
- **processing-service**: https://processing.wecando.click
- **storage-service**: https://storage.wecando.click

## 🔧 Configuração Técnica

### DNS Records (Route53)
```
api.wecando.click       A      <INGRESS_IP>
auth.wecando.click      CNAME  api.wecando.click
upload.wecando.click    CNAME  api.wecando.click
processing.wecando.click CNAME api.wecando.click
storage.wecando.click   CNAME  api.wecando.click
```

### SSL Certificates
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: fiapx-tls
spec:
  secretName: fiapx-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - auth.wecando.click
  - upload.wecando.click
  - processing.wecando.click
  - storage.wecando.click
```

### Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fiapx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://main.d13ms2nooclzwx.amplifyapp.com"
```

## 💰 Custos

### ✅ **Low Cost Solution**
- **cert-manager**: Gratuito
- **nginx-ingress**: Gratuito
- **Let's Encrypt**: Gratuito
- **Route53**: ~$0.50/mês por hosted zone
- **DNS Queries**: ~$0.40 por milhão

### 💡 **Total Estimado**: < $1/mês

## 🔍 Troubleshooting

### Verificar Certificados
```bash
kubectl get certificate
kubectl describe certificate fiapx-tls
```

### Verificar Ingress
```bash
kubectl get ingress
kubectl describe ingress fiapx-ingress
```

### Testar Endpoints
```bash
curl -I https://auth.wecando.click/health
curl -I https://upload.wecando.click/health
curl -I https://processing.wecando.click/health
curl -I https://storage.wecando.click/health
```

### Logs cert-manager
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

### Logs nginx-ingress
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## ✅ Resultado Final

### 🎯 **Mixed Content Resolvido**
- ✅ Frontend HTTPS → Backend HTTPS
- ✅ Comunicação segura end-to-end
- ✅ Certificados SSL válidos
- ✅ CORS configurado corretamente

### 🏗️ **Arquitetura Moderna**
- ✅ 100% AWS resources
- ✅ ARM64 optimized
- ✅ Auto-renewable certificates
- ✅ Scalable ingress
- ✅ Production-ready

### 💸 **Low Cost**
- ✅ Sem Application Load Balancer
- ✅ Recursos gratuitos (cert-manager, nginx)
- ✅ Let's Encrypt gratuito
- ✅ Mínimo custo Route53

## 🎉 Status

**PRONTO PARA EXECUÇÃO**: Execute os scripts na ordem indicada para resolver completamente o problema de Mixed Content com uma solução robusta, simples e low-cost usando 100% recursos AWS e arquitetura ARM64.

---

*Solução criada para FIAP X - 27/06/2025*
