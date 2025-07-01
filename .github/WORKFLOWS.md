# Configuração de Workflows GitHub Actions
# Este arquivo documenta os workflows disponíveis e suas configurações

## Workflows Disponíveis

### 1. ci-cd.yml
**Descrição**: Pipeline principal de CI/CD para todos os microsserviços
**Trigger**: 
- Push nas branches main/develop
- Pull requests para main
- Tags com formato v*

**Jobs**:
- test: Testes unitários, integração e E2E
- security: Scans de segurança (Gosec, Trivy)
- build: Build e push de imagens Docker
- deploy: Deploy automático no Kubernetes
- notify: Notificações de status

**Microsserviços incluídos**:
- auth-service
- upload-service
- processing-service
- storage-service
- notification-service

### 2. deploy-notification-service.yml  
**Descrição**: Deploy específico do notification-service
**Trigger**:
- Push em arquivos do diretório notification-service/
- Execução manual com parâmetros

**Parâmetros Manuais**:
- force_deploy: boolean (padrão: false)
- image_tag: string (padrão: latest)

**Jobs**:
- changes: Detecção de mudanças
- test: Testes específicos do notification-service
- security: Scan de segurança
- build: Build e push da imagem
- deploy: Deploy via SSH no Kubernetes
- notify: Notificações e comentários em PR

### 3. deploy-fiapx-https.yml
**Descrição**: Deploy do frontend com HTTPS
**Trigger**: Execução manual
**Parâmetros**:
- node_ips: Lista de IPs dos nodes
- domain: Domínio (padrão: fiapx.wecando.click)
- force_frontend_rebuild: boolean (padrão: false)

## Secrets Necessários

### Docker Hub
```bash
DOCKER_USERNAME=seu_usuario_dockerhub
DOCKER_PASSWORD=seu_token_dockerhub
```

### Kubernetes (SSH)
```bash
SSH_PRIVATE_KEY=sua_chave_privada_ssh
SSH_USER=ubuntu
K8S_HOST=ip_do_node_kubernetes
```

### AWS (opcional - para recursos AWS)
```bash
AWS_ACCESS_KEY_ID=sua_access_key
AWS_SECRET_ACCESS_KEY=sua_secret_key
AWS_REGION=us-east-1
```

## Como Usar

### Deploy Automático
1. Faça push de mudanças na branch main
2. O workflow ci-cd.yml será executado automaticamente
3. Se houver mudanças no notification-service/, o workflow específico também será executado

### Deploy Manual do Notification Service
1. Vá para Actions no GitHub
2. Selecione "Deploy Notification Service"
3. Clique em "Run workflow"
4. Configure os parâmetros se necessário
5. Execute

### Monitoramento
1. Veja os logs em Actions > Workflow runs
2. Use os scripts locais para monitoramento:
   ```bash
   ./infrastructure/scripts/monitor-notification-service.sh --watch
   ```

### Troubleshooting
1. Verifique se todos os secrets estão configurados
2. Valide conectividade SSH com o cluster
3. Verifique se as imagens Docker estão sendo criadas corretamente
4. Use o script de rollback se necessário:
   ```bash
   ./infrastructure/scripts/rollback-notification-service.sh
   ```

## Boas Práticas

### Desenvolvimento
1. Sempre teste localmente antes do push
2. Use branches feature para desenvolvimento
3. Crie PRs para revisão antes do merge na main

### Deploy
1. Monitore os logs durante o deploy
2. Verifique a saúde dos serviços após o deploy
3. Tenha sempre um plano de rollback

### Segurança
1. Nunca commitr secrets no código
2. Use secrets do GitHub/Kubernetes
3. Execute security scans regularmente
4. Mantenha as dependências atualizadas

## Estrutura de Arquivos

```
.github/
├── workflows/
│   ├── ci-cd.yml                    # Pipeline principal
│   ├── deploy-notification-service.yml  # Deploy específico
│   └── deploy-fiapx-https.yml       # Deploy frontend HTTPS
└── WORKFLOWS.md                     # Este arquivo

infrastructure/
├── scripts/
│   ├── test-notification-deployment.sh
│   ├── monitor-notification-service.sh
│   └── rollback-notification-service.sh
└── kubernetes/
    └── notification-service.yaml
```
