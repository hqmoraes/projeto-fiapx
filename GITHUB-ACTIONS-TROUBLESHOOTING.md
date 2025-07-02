# 🔧 GUIA DE TROUBLESHOOTING - GITHUB ACTIONS E SECRETS

## 🚨 PROBLEMAS COMUNS E SOLUÇÕES

### 1. 🔑 FALHA DE AUTENTICAÇÃO NO DOCKER HUB

**Erro típico:**
```
Error: Error response from daemon: Get "https://registry-1.docker.io/v2/": unauthorized: incorrect username or password
```

**Possíveis causas:**
- Token do Docker Hub expirado
- Username incorreto (deve ser `hmoraes`, não `hqmoraes`)
- Secret não configurada ou nome errado

**Solução:**
1. Verifique o nome da secret (deve ser `DOCKER_USERNAME` e `DOCKER_PASSWORD`)
2. Regenere o token em https://hub.docker.com/settings/security
3. Atualize a secret no GitHub:
   ```bash
   gh secret set DOCKER_PASSWORD -b "dckr_pat_new_token_here" -R hqmoraes/projeto-fiapx
   ```

### 2. 📛 FALHA NO DEPLOY KUBERNETES

**Erro típico:**
```
error: error loading config file "/tmp/kubeconfig": yaml: line 2: did not find expected <document start>
```

**Possíveis causas:**
- `KUBE_CONFIG` não está corretamente encodada em base64
- Arquivo kubeconfig inválido
- Certificados expirados

**Solução:**
1. Regenere o arquivo kubeconfig:
   ```bash
   kubectl config view --raw > kubeconfig.yaml
   ```
2. Encode corretamente em base64 (sem quebras de linha):
   ```bash
   cat kubeconfig.yaml | base64 -w 0
   ```
3. Atualize a secret:
   ```bash
   gh secret set KUBE_CONFIG -b "$(cat kubeconfig.yaml | base64 -w 0)" -R hqmoraes/projeto-fiapx
   ```

### 3. 🔒 ERRO DE ACESSO SSH

**Erro típico:**
```
Permission denied (publickey).
fatal: Could not read from remote repository.
```

**Possíveis causas:**
- Chave SSH privada incorreta
- Usuário SSH incorreto
- Chave não está no `authorized_keys` do servidor

**Solução:**
1. Verifique se a chave pública está no servidor:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub usuario@servidor
   ```
2. Teste a conexão SSH manualmente:
   ```bash
   ssh -i ~/.ssh/id_rsa usuario@servidor
   ```
3. Atualize as secrets SSH_PRIVATE_KEY e SSH_USER

### 4. 📦 FALHA AO REALIZAR BUILD

**Erro típico:**
```
The process '/usr/bin/docker' failed with exit code 1
```

**Possíveis causas:**
- Erro no Dockerfile
- Falta de dependências
- Permissões insuficientes no Docker Hub

**Solução:**
1. Teste o build localmente:
   ```bash
   docker build -t test-image ./auth-service
   ```
2. Verifique as permissões do token do Docker Hub
3. Aumente o timeout do job:
   ```yaml
   jobs:
     build:
       timeout-minutes: 20
   ```

### 5. 🔍 SECRETS APARECENDO NOS LOGS

**Erro típico:**
Credenciais visíveis nos logs do GitHub Actions

**Possíveis causas:**
- `echo` ou `print` de variáveis de ambiente secretas
- Debug excessivo em scripts

**Solução:**
1. Use `::add-mask::` para ocultar valores:
   ```yaml
   - run: |
       echo "::add-mask::${{ secrets.AWS_ACCESS_KEY_ID }}"
   ```
2. Evite logs de debug em produção
3. Use ferramentas como [trufflehog](https://github.com/trufflesecurity/trufflehog) para scan de secrets

### 6. 🧪 TESTES FALHANDO

**Erro típico:**
```
FAIL: TestAuthenticationFlow
```

**Possíveis causas:**
- Falta da secret JWT_SECRET
- Configuração incorreta de banco de dados para testes
- Dependências desatualizadas

**Solução:**
1. Verifique se todas as variáveis de ambiente necessárias estão definidas:
   ```yaml
   env:
     DATABASE_URL: postgres://fiapx_test:test_password_secure_123@localhost:5432/fiapx_test?sslmode=disable
     JWT_SECRET: ${{ secrets.JWT_SECRET || 'test-jwt-secret-for-ci' }}
   ```
2. Atualize dependências: `go mod tidy`

### 7. 📊 FALHA EM HEALTH CHECKS

**Erro típico:**
```
Error: Process completed with exit code 1.
curl: (22) The requested URL returned error: 503 Service Unavailable
```

**Possíveis causas:**
- Aplicação não iniciou corretamente
- Problemas de rede ou DNS
- Erro na aplicação

**Solução:**
1. Aumente o timeout e retries:
   ```yaml
   - name: Health check
     run: |
       for i in {1..10}; do
         if curl -f --max-time 30 https://fiapx.wecando.click/health; then
           echo "✅ Health check passed"
           exit 0
         fi
         sleep 30
       done
       exit 1
   ```
2. Verifique logs da aplicação:
   ```bash
   kubectl logs -l app=auth-service --tail=100
   ```

## 🔄 FERRAMENTAS DE DIAGNÓSTICO

### 1. 🔍 Verificar Status dos Workflows
```bash
gh run list -R hqmoraes/projeto-fiapx --limit 10
```

### 2. 📊 Visualizar Detalhes de um Workflow
```bash
gh run view <run-id> -R hqmoraes/projeto-fiapx
```

### 3. 📜 Visualizar Logs de um Workflow
```bash
gh run view <run-id> --log -R hqmoraes/projeto-fiapx
```

### 4. 🛠️ Testar Workflow Localmente
Usando [act](https://github.com/nektos/act):
```bash
act -s DOCKER_USERNAME=hmoraes -s DOCKER_PASSWORD=secret
```

### 5. 🔐 Verificar Secrets Configuradas
```bash
./check-github-secrets.sh
```

## 📞 CANAIS DE SUPORTE

Se os problemas persistirem após tentar as soluções acima:

1. **GitHub Actions Issues**:
   - [GitHub Community Support](https://github.community/c/actions/41)
   - [GitHub Actions Documentation](https://docs.github.com/en/actions)

2. **Suporte Interno**:
   - DevOps Team: devops@fiapx.com
   - Slack: #devops-support

3. **Suporte Docker Hub**:
   - [Docker Hub Support](https://hub.docker.com/support)

4. **Suporte Kubernetes**:
   - [Kubernetes Troubleshooting Guide](https://kubernetes.io/docs/tasks/debug/)

---

> 🔔 **LEMBRETE**: Mantenha logs detalhados de todas as tentativas de troubleshooting para referência futura e para facilitar o diagnóstico de problemas recorrentes.
