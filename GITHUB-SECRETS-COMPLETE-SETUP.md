# 🔐 CONFIGURAÇÃO COMPLETA DE SECRETS GITHUB - FIAP-X

## 📋 RESUMO DAS SECRETS NECESSÁRIAS

Baseado na análise dos workflows do GitHub Actions, identifiquei **10 secrets diferentes** que precisam ser configuradas para o CI/CD funcionar completamente.

## ⚠️ CREDENCIAIS CORRETAS

### 👤 Usuários:
- **GitHub**: `hqmoraes` 
- **Docker Hub**: `hmoraes` ⚠️ (diferente do GitHub!)
- **AWS**: conforme sua conta específica

## 🚨 ALERTA DE SEGURANÇA

**CREDENCIAIS EXPOSTAS ENCONTRADAS NO REPOSITÓRIO!**

Execute imediatamente:
```bash
./security-cleanup.sh
```

Veja detalhes em: `SECURITY-ALERT-EXPOSED-CREDENTIALS.md`

## 🐳 SECRETS DO DOCKER HUB

### Variações Encontradas nos Workflows:
```yaml
# Arquivo: ci-cd.yml
DOCKER_USERNAME
DOCKER_PASSWORD

# Arquivo: deploy-fiapx-https.yml  
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN

# Arquivo: deploy-notification-service.yml
DOCKER_USERNAME
DOCKER_PASSWORD
```

### ⚠️ PROBLEMA IDENTIFICADO:
Os workflows usam **nomes inconsistentes** para as secrets do Docker Hub. Isso pode causar falhas no CI/CD.

## 🛠️ TODAS AS SECRETS NECESSÁRIAS

### 1. 🐳 Docker Hub (2 secrets)
```bash
DOCKER_USERNAME=hmoraes                     # Seu username do Docker Hub
DOCKERHUB_USERNAME=hmoraes                  # Variação do nome (manter ambos)
DOCKER_PASSWORD=dckr_pat_xxxxxxxxxxxxx      # Docker Hub Personal Access Token
DOCKERHUB_TOKEN=dckr_pat_xxxxxxxxxxxxx      # Variação do nome (manter ambos)
```

### 2. ☸️ Kubernetes (1 secret)
```bash
KUBE_CONFIG=<conteudo-do-kubeconfig-yaml>   # Arquivo kubeconfig completo em base64
```

### 3. 🔑 SSH Access (3 secrets)
```bash
SSH_PRIVATE_KEY=<ssh-private-key>           # Chave SSH privada para acesso ao servidor
SSH_USER=<username>                         # Username SSH (exemplo: ubuntu, ec2-user)
K8S_HOST=<server-ip-or-domain>             # IP ou domínio do servidor K8s
```

### 4. ☁️ AWS (2 secrets)
```bash
AWS_ACCESS_KEY_ID=AKIA...                  # AWS Access Key
AWS_SECRET_ACCESS_KEY=...                  # AWS Secret Key
```

### 5. 🔐 Application (2 secrets)
```bash
JWT_SECRET=<base64-encoded-secret>          # Secret para JWT tokens
```

## 🚀 COMO CONFIGURAR AS SECRETS

### Método 1: GitHub CLI (Recomendado)
```bash
# 1. Instalar GitHub CLI
# Ubuntu/Debian: apt install gh
# macOS: brew install gh

# 2. Fazer login
gh auth login

# 3. Configurar secrets para o repositório principal
REPO="hqmoraes/projeto-fiapx"

# Docker Hub
gh secret set DOCKER_USERNAME -b "hmoraes" -R $REPO
gh secret set DOCKERHUB_USERNAME -b "hmoraes" -R $REPO
gh secret set DOCKER_PASSWORD -b "dckr_pat_XXXXXXXXXXXXXXX" -R $REPO
gh secret set DOCKERHUB_TOKEN -b "dckr_pat_XXXXXXXXXXXXXXX" -R $REPO

# Kubernetes
gh secret set KUBE_CONFIG -b "$(cat kubeconfig.yaml | base64 -w 0)" -R $REPO

# SSH
gh secret set SSH_PRIVATE_KEY -b "$(cat ~/.ssh/id_rsa)" -R $REPO
gh secret set SSH_USER -b "ubuntu" -R $REPO
gh secret set K8S_HOST -b "your-server-ip" -R $REPO

# AWS (se necessário)
gh secret set AWS_ACCESS_KEY_ID -b "AKIA..." -R $REPO
gh secret set AWS_SECRET_ACCESS_KEY -b "..." -R $REPO

# JWT
gh secret set JWT_SECRET -b "$(openssl rand -base64 32)" -R $REPO
```

### Método 2: Interface Web do GitHub
1. Acesse: `https://github.com/hqmoraes/projeto-fiapx/settings/secrets/actions`
2. Clique em "New repository secret"
3. Adicione cada secret da lista acima
4. Clique em "Add secret"

## 🔍 VALIDAÇÃO DAS SECRETS

### Script de Verificação:
```bash
#!/bin/bash
echo "🔍 Verificando secrets configuradas..."

REPO="hqmoraes/projeto-fiapx"

secrets=(
    "DOCKER_USERNAME"
    "DOCKERHUB_USERNAME" 
    "DOCKER_PASSWORD"
    "DOCKERHUB_TOKEN"
    "KUBE_CONFIG"
    "SSH_PRIVATE_KEY"
    "SSH_USER"
    "K8S_HOST"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "JWT_SECRET"
)

for secret in "${secrets[@]}"; do
    if gh secret list -R $REPO | grep -q "$secret"; then
        echo "✅ $secret - Configurada"
    else
        echo "❌ $secret - FALTANDO"
    fi
done
```

## 🏗️ COMO OBTER OS VALORES DAS SECRETS

### 🐳 Docker Hub Token:
1. Acesse: https://hub.docker.com/settings/security
2. Clique em "New Access Token"
3. Nome: "GitHub Actions CI/CD"
4. Permissions: "Read, Write, Delete"
5. Copie o token gerado (formato: `dckr_pat_...`)

### ☸️ Kubeconfig:
```bash
# Se estiver usando o arquivo local
cat ~/.kube/config | base64 -w 0

# Se estiver no servidor
scp user@server:~/.kube/config ./kubeconfig-server.yaml
cat kubeconfig-server.yaml | base64 -w 0
```

### 🔑 SSH Key:
```bash
# Gerar nova chave SSH (se necessário)
ssh-keygen -t rsa -b 4096 -C "github-actions@fiapx"

# Usar chave existente
cat ~/.ssh/id_rsa

# Adicionar chave pública ao servidor
ssh-copy-id user@server
```

### ☁️ AWS Credentials:
1. Acesse: https://console.aws.amazon.com/iam/home#/security_credentials
2. Clique em "Create access key"
3. Selecione "Command Line Interface (CLI)"
4. Copie Access Key ID e Secret Access Key

## 🚨 CORREÇÕES NECESSÁRIAS NOS WORKFLOWS

### Inconsistência nos nomes das secrets:
1. **ci-cd.yml** usa: `DOCKER_USERNAME`, `DOCKER_PASSWORD`
2. **deploy-fiapx-https.yml** usa: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
3. **deploy-notification-service.yml** usa: `DOCKER_USERNAME`, `DOCKER_PASSWORD`

### ✅ SOLUÇÃO:
Configurar TODAS as variações para garantir compatibilidade:
- `DOCKER_USERNAME` + `DOCKERHUB_USERNAME` (mesmo valor)
- `DOCKER_PASSWORD` + `DOCKERHUB_TOKEN` (manter ambos)

## 🔄 INTEGRAÇÃO DO CI/CD COM SECRETS

### Workflow Principal (production-cicd.yml):
Este workflow principal usa as seguintes secrets:

```yaml
# Docker Hub
username: ${{ secrets.DOCKER_USERNAME }}
password: ${{ secrets.DOCKER_PASSWORD }}

# Kubernetes Config
KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}

# Application Secrets
JWT_SECRET: ${{ secrets.JWT_SECRET }}
```

### Deployment HTTPS (deploy-fiapx-https.yml):
Este workflow usa:

```yaml
# AWS
aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

# Docker Hub
username: ${{ secrets.DOCKER_USERNAME }}
password: ${{ secrets.DOCKER_PASSWORD }}

# SSH para acesso ao servidor
SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
SSH_USER: ${{ secrets.SSH_USER }}
K8S_HOST: ${{ secrets.K8S_HOST }}
```

## 🔐 GERENCIAMENTO DE CREDENCIAIS

### 🔄 Rotação de Secrets
Recomenda-se a rotação periódica das seguintes credenciais:

| Secret | Frequência | Procedimento |
|--------|------------|--------------|
| Docker Hub Token | 90 dias | Revogar token antigo em hub.docker.com e criar novo |
| AWS Credentials | 90 dias | Criar nova chave e desativar antiga no console AWS |
| JWT_SECRET | 180 dias | Gerar nova secret, atualizar nos serviços e depois no GitHub |
| SSH Keys | 365 dias | Gerar novo par de chaves, atualizar authorized_keys no servidor |

### 📊 Monitoramento de Acesso
Verifique regularmente:
1. Logs de acesso no Docker Hub
2. Atividade da conta AWS
3. Logs de acesso SSH ao servidor
4. Histórico de execução de workflows no GitHub Actions

## 🌱 CI/CD PARA BRANCHES

### 🧪 Branch `validar` (staging)
- Build e push de imagens Docker com tag específica
- Deploy no ambiente de staging
- Testes automatizados de integração

### 🚀 Branch `main` (produção)
- Build e push de imagens Docker com tag `latest`
- Deploy no ambiente de produção
- Health checks pós-deploy
- Rollback automático em caso de falha

## 📋 CHECKLIST DE VERIFICAÇÃO

Antes de executar o primeiro deploy completo:

- [ ] Todas as 10 secrets configuradas no GitHub
- [ ] Testes unitários passando
- [ ] Workflows padronizados (DOCKER_USERNAME e DOCKER_PASSWORD)
- [ ] Branch protection configurada para `main` e `validar`
- [ ] PR template configurado
- [ ] CODEOWNERS configurado
- [ ] Permissões de acesso ao repositório revisadas

## 🚨 RESOLUÇÃO DE PROBLEMAS

### Erro: "Authentication required"
```
Error: Error response from daemon: authentication required
```
**Solução**: Verifique as secrets `DOCKER_USERNAME` e `DOCKER_PASSWORD`. O token do Docker Hub pode ter expirado.

### Erro: "Unable to connect to the server"
```
error: unable to connect to the server: dial tcp: lookup cluster-name on X.X.X.X:53: no such host
```
**Solução**: Verifique a secret `KUBE_CONFIG` e se o certificado não expirou.

### Erro: "Permission denied (publickey)"
```
Permission denied (publickey).
```
**Solução**: Verifique `SSH_PRIVATE_KEY` e `SSH_USER`. Confirme que a chave pública está no authorized_keys do servidor.

## 📞 CONTATOS DE SUPORTE

- **Problemas de CI/CD**: DevOps Team (devops@fiapx.com)
- **Acesso AWS**: Cloud Team (cloud@fiapx.com)
- **Acesso Kubernetes**: Platform Team (platform@fiapx.com)
- **Acesso GitHub**: Security Team (security@fiapx.com)

---

> **⚠️ IMPORTANTE:** Mantenha essas secrets seguras e nunca as exponha em logs ou commits!

## 🔒 SEGURANÇA E BOAS PRÁTICAS

### 📁 Arquivos Sensíveis no .gitignore
O `.gitignore` foi atualizado para incluir todos os tipos de arquivos sensíveis:

```gitignore
# Chaves SSH
*.pem
*.key
id_rsa*
id_ed25519*

# Configurações Docker Hub
.docker/config.json
dockerhub-token.txt

# Certificados SSL/TLS
*.crt
*.cert
*.cer

# Credenciais e tokens
*-credentials.json
*-token.txt
*-apikey.txt
secrets.json
secrets.yaml

# Kubeconfig
kubeconfig*.yaml
!kubeconfig-template.yaml
```

### 🛡️ Verificações de Segurança
```bash
# Verificar se não há credenciais commitadas
git log --all --full-history -- "*.key" "*.pem" "*secret*" "*token*"

# Verificar .gitignore
git check-ignore -v arquivo-sensivel.key

# Remover arquivo sensível do histórico (se necessário)
git filter-branch --force --index-filter \
'git rm --cached --ignore-unmatch arquivo-sensivel.key' \
--prune-empty --tag-name-filter cat -- --all
```

### 🔄 Rotação de Secrets
**Recomendado fazer rotação a cada 90 dias:**
1. Docker Hub Token
2. SSH Keys
3. JWT Secret
4. AWS Credentials

### 👥 Usuários Corretos
- **GitHub**: `hqmoraes` 
- **Docker Hub**: `hmoraes`
- **AWS**: conforme sua conta

## 🔒 SEGURANÇA AVANÇADA PARA GITHUB ACTIONS

### 📊 Melhores Práticas de Segurança

#### 1. Permissões de Token Mínimas
Sempre configure permissões mínimas para o token GITHUB_TOKEN:

```yaml
permissions:
  contents: read
  packages: write
  pull-requests: write
  security-events: write
  id-token: write  # Apenas se necessário para OIDC
```

#### 2. Fixação de Versões de Actions
Sempre use versões específicas (não `@master` ou `@main`):

```yaml
# ❌ NÃO FAÇA ISSO
uses: actions/checkout@master

# ✅ FAÇA ISSO
uses: actions/checkout@v4
```

#### 3. Proteção contra Injeção de Comandos
Escape inputs corretamente:

```yaml
# ❌ NÃO FAÇA ISSO
run: echo ${{ github.event.issue.title }}

# ✅ FAÇA ISSO
run: echo "${{ github.event.issue.title }}"
```

#### 4. Análise Estática de Workflows
Use ferramentas como:
- [ActionsLint](https://github.com/actions-security/workflow-security-action)
- [GitHub Action Security Analysis](https://github.com/marketplace/actions/github-action-security-analysis)

### 🛡️ OpenID Connect (OIDC) para Nuvem

Se estiver usando AWS:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/my-github-actions-role
          aws-region: us-east-1
```

### 🔐 Gerenciamento de Secrets Avançado

#### 1. Criptografia de Secrets em Repositório
Considere usar [git-crypt](https://github.com/AGWA/git-crypt) ou [SOPS](https://github.com/mozilla/sops) para arquivos criptografados no repositório.

#### 2. Integrações com Cofres de Segredos
Para projetos grandes, considere a integração com:
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault

```yaml
steps:
  - name: Retrieve secrets from Vault
    uses: hashicorp/vault-action@v2
    with:
      url: https://vault.example.com
      token: ${{ secrets.VAULT_TOKEN }}
      secrets: |
        secret/data/ci/aws accessKey | AWS_ACCESS_KEY_ID
        secret/data/ci/aws secretKey | AWS_SECRET_ACCESS_KEY
```

### 🧪 Testes de Segurança Automatizados

Inclua no CI:

1. **SCA (Software Composition Analysis)**:
```yaml
- name: Run Dependency Check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'FIAP-X'
    path: '.'
    format: 'HTML'
    out: 'reports'
```

2. **SAST (Static Application Security Testing)**:
```yaml
- name: Run CodeQL Analysis
  uses: github/codeql-action/analyze@v2
```

3. **Scan de Secrets**:
```yaml
- name: Secret Scan
  uses: trufflesecurity/trufflehog@main
  with:
    path: ./
    base: ${{ github.event.repository.default_branch }}
    head: HEAD
    extra_args: --debug --only-verified
```

### 🔍 Auditoria e Compliance

#### 1. Logs de Acesso e Ações
Mantenha um histórico de execuções de workflow para auditoria:

```bash
# Exportar logs para análise
gh run list -R hqmoraes/projeto-fiapx --limit 100 --json databaseId,status,conclusion,name,event,headBranch,url > workflow_audit_logs.json
```

#### 2. Documentação de Configurações
Mantenha documentação atualizada de:
- Todas as secrets usadas
- Políticas de permissões
- Configurações de branch protection
- Processos de rotação de credenciais

### 📱 Notificações de Segurança

Configure alertas para:
1. Falhas em workflows de segurança
2. Execuções em branches protegidas
3. Alterações em arquivos de workflow
4. Detecção de credenciais expostas

```yaml
- name: Send security alert
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    channel-id: 'security-alerts'
    slack-message: ':rotating_light: Falha no scan de segurança: ${{ github.workflow }}'
  env:
    SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

## 📆 PLANO DE IMPLEMENTAÇÃO

Para garantir a configuração adequada de todas as secrets e controles de segurança, recomendamos seguir este plano de implementação estruturado:

### 📅 Cronograma de Implementação

| Fase | Atividade | Responsável | Prazo | Dependências |
|------|-----------|-------------|-------|--------------|
| **1. Limpeza** | Execução do script security-cleanup.sh | DevOps | Dia 1 | Nenhuma |
| | Revisão dos arquivos sensíveis identificados | Segurança | Dia 1 | - |
| | Atualização do .gitignore | DevOps | Dia 1 | - |
| **2. Configuração** | Setup das secrets do Docker Hub | DevOps | Dia 2 | Fase 1 |
| | Setup das secrets do Kubernetes | DevOps | Dia 2 | Fase 1 |
| | Setup das secrets de SSH | DevOps | Dia 2 | Fase 1 |
| | Setup das secrets da AWS | DevOps | Dia 2 | Fase 1 |
| | Setup do JWT_SECRET | DevOps | Dia 2 | Fase 1 |
| **3. Validação** | Execução do check-github-secrets.sh | DevOps | Dia 3 | Fase 2 |
| | Correção de inconsistências nos workflows | DevOps | Dia 3 | Fase 2 |
| | Execução do validate-workflows.sh | DevOps | Dia 3 | - |
| **4. Proteção** | Configuração de branch protection | Admin | Dia 4 | Fase 3 |
| | Configuração de CODEOWNERS | DevOps | Dia 4 | - |
| | Configuração de pre-commit hooks | Desenvolvedores | Dia 4 | - |
| **5. Teste** | Commit de teste para validar pipeline | DevOps | Dia 5 | Fase 4 |
| | PR de teste para validação | DevOps | Dia 5 | Fase 4 |
| | Merge para main para validar deploy | Admin | Dia 5 | - |
| **6. Monitoramento** | Configuração de alertas | DevOps | Dia 6 | Fase 5 |
| | Implementação do dashboard | DevOps | Dia 6 | - |
| | Configuração de auditorias periódicas | Segurança | Dia 6 | - |
| **7. Documentação** | Finalização da documentação | DevOps | Dia 7 | Todas |
| | Treinamento da equipe | DevOps/Segurança | Dia 7 | - |
| | Entrega do projeto | Todos | Dia 7 | - |

### 🔄 Ciclo de Manutenção

Após a implementação inicial, estabeleça o seguinte ciclo de manutenção:

| Frequência | Atividade | Responsável |
|------------|-----------|-------------|
| **Diária** | Verificação de logs de CI/CD | DevOps |
| | Monitoramento de alertas | DevOps |
| **Semanal** | Execução do check-github-secrets.sh | Automatizado |
| | Verificação de dependências | Automatizado (Dependabot) |
| **Mensal** | Auditoria de acessos | Segurança |
| | Revisão de permissões | Admin |
| **Trimestral** | Rotação de Docker Hub tokens | DevOps |
| | Rotação de AWS credentials | DevOps |
| **Semestral** | Rotação de JWT_SECRET | DevOps |
| | Revisão completa de segurança | Segurança |
| **Anual** | Rotação de SSH keys | DevOps |
| | Revisão da documentação | DevOps/Segurança |

### 📊 Métricas de Sucesso

Para avaliar a eficácia da implementação, monitore as seguintes métricas:

1. **Cobertura de Secrets**:
   - Meta: 100% das secrets configuradas corretamente
   - Verificação: Execução de check-github-secrets.sh

2. **Taxa de Sucesso do CI/CD**:
   - Meta: >95% de builds e deploys bem-sucedidos
   - Verificação: Dashboard de CI/CD

3. **Tempo de Detecção de Problemas**:
   - Meta: <30 minutos para detecção de falhas
   - Verificação: Logs e alertas

4. **Tempo de Resposta a Incidentes**:
   - Meta: <2 horas para mitigação de exposição de secrets
   - Verificação: Registros de incidentes

5. **Aderência ao Cronograma de Rotação**:
   - Meta: 100% das rotações de secrets realizadas no prazo
   - Verificação: Logs de rotação

### 🚀 Plano de Continuidade

Para garantir a segurança contínua após a implementação inicial:

1. **Documentação Viva**:
   - Mantenha este documento atualizado com novas práticas
   - Registre lições aprendidas de incidentes

2. **Automação Progressiva**:
   - Automatize mais aspectos da verificação e rotação
   - Integre validações adicionais ao pipeline

3. **Expansão de Escopo**:
   - Estenda o modelo para outros repositórios
   - Incorpore validações de segurança adicionais

4. **Treinamento Contínuo**:
   - Realize sessões trimestrais de atualização
   - Capacite novos membros da equipe

## 🏁 CONSIDERAÇÕES FINAIS

A implementação de um sistema robusto de gerenciamento de secrets para CI/CD é um processo contínuo que requer vigilância, manutenção e melhoria constante. Este documento serve como ponto de partida e referência para garantir que as melhores práticas sejam seguidas consistentemente.

Lembre-se:
- A segurança é responsabilidade de todos na equipe
- A automação reduz erros humanos e garante consistência
- A transparência e documentação facilitam a manutenção a longo prazo
- A resposta rápida a incidentes minimiza danos potenciais

Com estas diretrizes, configurações e práticas, o projeto FIAP-X está bem posicionado para manter um pipeline de CI/CD seguro, confiável e eficiente.

---

**Documento Aprovado Por**:  
DevOps Team | Security Team | Admin Team

**Última Revisão**: 2 de julho de 2025
