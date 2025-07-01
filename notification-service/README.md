# Notification Service

[![CI/CD](https://github.com/hqmoraes/projeto-fiapx/actions/workflows/notification-service.yml/badge.svg)](https://github.com/hqmoraes/projeto-fiapx/actions/workflows/notification-service.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/hqmoraes/projeto-fiapx/notification-service)](https://goreportcard.com/report/github.com/hqmoraes/projeto-fiapx/notification-service)
[![Security Scan](https://img.shields.io/badge/security-gosec-blue)](https://github.com/securecodewarrior/gosec)
[![Docker](https://img.shields.io/badge/docker-ready-blue)](https://hub.docker.com/r/hmoraes/notification-service)

## 📧 Descrição

O **Notification Service** é um microsserviço da plataforma **FIAP-X** responsável pelo envio automatizado de notificações por email para usuários. Ele monitora eventos de processamento de vídeos através do RabbitMQ e envia notificações personalizadas sobre status de operações (sucesso, erro, processamento em andamento).

### ✨ Características Principais

- **🔒 Segurança**: Containerização com usuário não-root, imagem distroless, sem credenciais hardcoded
- **⚡ Performance**: Processamento assíncrono com RabbitMQ, retry automático
- **📊 Observabilidade**: Logs estruturados, health checks, métricas
- **🔧 CI/CD**: Pipeline automatizado com testes, lint, security scan
- **☁️ Cloud-Native**: Deploy em Kubernetes com Amazon SES

## 🛠️ Tecnologias

- **Linguagem**: Go 1.21+
- **Messaging**: RabbitMQ (AMQP)
- **Email**: Amazon SES (SMTP)
- **Templates**: HTML com Go Templates
- **Containerização**: Docker (multi-stage, distroless)
- **Orquestração**: Kubernetes
- **Monitoramento**: Prometheus-ready
- **CI/CD**: GitHub Actions
- **Segurança**: Gosec, Distroless images, Non-root user

## Estrutura do Projeto

```
notification-service/
├── cmd/
│   └── notification-service/
│       └── main.go              # Aplicação principal
├── templates/                   # Templates de email HTML
├── tests/                      # Testes unitários
├── Dockerfile                  # Imagem Docker
├── go.mod                      # Dependências Go
└── go.sum                      # Checksums das dependências
```

## Funcionalidades

### 📧 Sistema de Email
- Envio de emails via SMTP (Gmail/Google Workspace)
- Templates HTML responsivos e personalizados
- Suporte a múltiplos idiomas
- Retry automático em caso de falha

### 🔄 Integração com RabbitMQ
- Consumer de mensagens de notificação
- Queue durável com acknowledgment
- Processamento assíncrono de mensagens
- Dead letter queue para mensagens com falha

### 📋 Tipos de Notificação
- **Sucesso**: Processamento de vídeo concluído
- **Erro**: Falha no processamento
- **Processamento**: Vídeo entrou na fila
- **Genérica**: Outras atualizações

## Variáveis de Ambiente

### SMTP Configuration
```bash
# Gmail/Google Workspace
SMTP_HOST=smtp.gmail.com        # Servidor SMTP
SMTP_PORT=587                   # Porta SMTP (TLS)
SMTP_USERNAME=your@gmail.com    # Email remetente
SMTP_PASSWORD=app-password      # Senha de app (não a senha normal)

# Email Settings
FROM_EMAIL=noreply@fiapx.wecando.click  # Email de origem
FROM_NAME=FIAP-X Platform               # Nome do remetente
```

### RabbitMQ
```bash
RABBITMQ_URL=amqp://guest:guest@rabbitmq-service:5672/
```

### Desenvolvimento
```bash
# Para teste de email
SEND_TEST_EMAIL=true           # Habilita envio de email de teste
TEST_EMAIL=test@example.com    # Email de destino para teste

# Usuário padrão (mock)
DEFAULT_USER_EMAIL=user@fiapx.wecando.click
DEFAULT_USER_NAME=FIAP-X User
```

## Configuração Gmail

### 1. Habilitar 2FA
1. Acesse [Google Account Settings](https://myaccount.google.com/)
2. Vá em **Security** → **2-Step Verification**
3. Habilite a verificação em duas etapas

### 2. Criar App Password
1. Acesse [App Passwords](https://myaccount.google.com/apppasswords)
2. Selecione **Mail** e **Other (Custom name)**
3. Digite "FIAP-X Notifications"
4. Use a senha gerada no `SMTP_PASSWORD`

### 3. Configurar Less Secure Apps (se necessário)
Se não usar App Password, habilite acesso para apps menos seguros:
1. Acesse [Less secure app access](https://myaccount.google.com/lesssecureapps)
2. Habilite o acesso

## Templates de Email

### Template de Sucesso
```html
<!DOCTYPE html>
<html>
<head>
    <title>Processamento Concluído</title>
    <style>/* CSS styling */</style>
</head>
<body>
    <div class="container">
        <div class="header success">
            <h1>🎉 Vídeo Processado com Sucesso!</h1>
        </div>
        <div class="content">
            <p>Olá <strong>{{.UserName}}</strong>,</p>
            <p>Seu vídeo foi processado com sucesso!</p>
            <!-- Detalhes do vídeo -->
        </div>
    </div>
</body>
</html>
```

### Template de Erro
```html
<!DOCTYPE html>
<html>
<head>
    <title>Erro no Processamento</title>
    <style>/* CSS styling */</style>
</head>
<body>
    <div class="container">
        <div class="header error">
            <h1>⚠️ Erro no Processamento</h1>
        </div>
        <div class="content">
            <p>Olá <strong>{{.UserName}}</strong>,</p>
            <p>Infelizmente ocorreu um erro durante o processamento.</p>
            <!-- Detalhes do erro -->
        </div>
    </div>
</body>
</html>
```

## Estrutura das Mensagens

### Mensagem de Notificação
```json
{
  "user_id": 123,
  "user_email": "user@example.com",
  "user_name": "João Silva",
  "video_id": "video_123456",
  "video_title": "Meu Vídeo.mp4",
  "status": "completed",
  "error_message": "",
  "processed_at": "2025-06-30 15:30:45",
  "type": "success"
}
```

### Status Suportados
- `completed` - Processamento concluído com sucesso
- `failed` / `error` - Erro no processamento
- `processing` - Processamento iniciado
- `pending` - Aguardando na fila

### Tipos de Notificação
- `success` - Notificação de sucesso
- `error` - Notificação de erro
- `info` / `warning` - Notificações informativas

## Instalação e Execução

### Pré-requisitos
- Go 1.22+
- RabbitMQ Server
- Conta Gmail com App Password
- Docker (opcional)

### Desenvolvimento Local

1. **Instalar dependências**:
```bash
go mod download
```

2. **Configurar variáveis de ambiente**:
```bash
export SMTP_HOST=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USERNAME=your@gmail.com
export SMTP_PASSWORD=your-app-password
export FROM_EMAIL=noreply@fiapx.wecando.click
export FROM_NAME="FIAP-X Platform"
export RABBITMQ_URL=amqp://guest:guest@localhost:5672/
```

3. **Executar o serviço**:
```bash
go run cmd/notification-service/main.go
```

### Teste de Email

1. **Teste rápido**:
```bash
SEND_TEST_EMAIL=true \
TEST_EMAIL=your@email.com \
go run cmd/notification-service/main.go
```

2. **Teste completo**:
```bash
# Configurar todas as variáveis
export SMTP_USERNAME=your@gmail.com
export SMTP_PASSWORD=your-app-password
export SEND_TEST_EMAIL=true
export TEST_EMAIL=recipient@example.com

# Executar
go run cmd/notification-service/main.go
```

### Docker

1. **Build da imagem**:
```bash
docker build -t notification-service:latest .
```

2. **Executar container**:
```bash
docker run \
  -e SMTP_USERNAME=your@gmail.com \
  -e SMTP_PASSWORD=your-app-password \
  -e RABBITMQ_URL=amqp://guest:guest@host.docker.internal:5672/ \
  notification-service:latest
```

### Kubernetes

1. **Configurar secrets**:
```bash
kubectl create secret generic email-secrets \
  --from-literal=smtp-username=your@gmail.com \
  --from-literal=smtp-password=your-app-password \
  --namespace=fiapx
```

2. **Deploy do serviço**:
```bash
kubectl apply -f infrastructure/kubernetes/notification-service.yaml
```

3. **Verificar status**:
```bash
kubectl get pods -l app=notification-service -n fiapx
kubectl logs -f deployment/notification-service -n fiapx
```

## Monitoramento e Logs

### Logs Estruturados
```bash
2025/06/30 15:30:45 📧 Email notification service started. Waiting for messages...
2025/06/30 15:31:02 Sending notification to user@example.com for video video_123 (status: completed)
2025/06/30 15:31:03 ✅ Email sent successfully to user@example.com
```

### Métricas
- **Emails enviados**: Contador de emails por status
- **Falhas de envio**: Rate de falhas de entrega
- **Tempo de processamento**: Latência de envio
- **Queue size**: Tamanho da fila de notificações

### Health Checks
```bash
# Verificar se o processo está rodando
ps aux | grep notification-service

# Verificar logs
kubectl logs -f deployment/notification-service -n fiapx

# Verificar fila RabbitMQ
kubectl exec -it rabbitmq-0 -n fiapx -- rabbitmqctl list_queues
```

## Troubleshooting

### Problemas Comuns

#### 1. Erro de autenticação SMTP
```
Error: 534-5.7.9 Application-specific password required
```
**Solução**: 
- Habilitar 2FA no Google
- Criar App Password
- Usar App Password no `SMTP_PASSWORD`

#### 2. Emails não sendo enviados
```
Error: failed to send email: dial tcp: connection refused
```
**Solução**:
- Verificar `SMTP_HOST` e `SMTP_PORT`
- Verificar firewall/proxy
- Confirmar credenciais

#### 3. Queue não processando mensagens
```
Error: failed to connect to RabbitMQ
```
**Solução**:
- Verificar `RABBITMQ_URL`
- Confirmar que RabbitMQ está rodando
- Verificar rede entre serviços

#### 4. Templates com erro
```
Error: template not found: success
```
**Solução**:
- Verificar templates no código
- Confirmar tipo de notificação
- Verificar sintaxe dos templates

### Comandos de Debug

#### Verificar configuração
```bash
# Testar conexão SMTP
telnet smtp.gmail.com 587

# Verificar variáveis de ambiente
kubectl exec -it deployment/notification-service -n fiapx -- env | grep SMTP

# Testar RabbitMQ
kubectl exec -it rabbitmq-0 -n fiapx -- rabbitmqctl status
```

#### Logs detalhados
```bash
# Logs em tempo real
kubectl logs -f deployment/notification-service -n fiapx

# Logs dos últimos eventos
kubectl get events -n fiapx | grep notification

# Logs do RabbitMQ
kubectl logs -f rabbitmq-0 -n fiapx
```

#### Teste manual de email
```bash
# Executar teste dentro do pod
kubectl exec -it deployment/notification-service -n fiapx -- /bin/sh -c "
    SEND_TEST_EMAIL=true \
    TEST_EMAIL=your@email.com \
    ./notification-service
"
```

## Integração com Outros Serviços

### Processing Service
O Processing Service envia mensagens de notificação quando:
- Processamento é concluído com sucesso
- Ocorre erro durante o processamento
- Vídeo entra na fila de processamento

### Auth Service
Integração futura para obter dados reais do usuário:
```go
// GET /auth/users/{userID}
type UserInfo struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}
```

### API Gateway
Possível endpoint para envio manual de notificações:
```
POST /api/notifications
{
  "user_id": 123,
  "type": "custom",
  "subject": "Título do email",
  "message": "Conteúdo personalizado"
}
```

## Segurança

### Implementações de Segurança Aplicadas

#### 📦 Containerização Segura
- **Imagem Distroless**: Uso de `gcr.io/distroless/static:nonroot` para minimizar superfície de ataque
- **Usuário Não-Root**: Container executa como usuário `nonroot` (UID 65532)
- **Read-Only Filesystem**: Sistema de arquivos somente leitura no container
- **Security Context**: Configurações de segurança no Kubernetes (capabilities drop, privilege escalation)

#### 🔐 Gestão de Credenciais
- **Kubernetes Secrets**: Credenciais SES armazenadas em secrets do K8s
- **Sem Hardcoded Secrets**: Nenhuma credencial no código fonte ou imagens
- **Variáveis de Ambiente**: Configuração sensível via env vars seguras
- **Arquivo .env.test**: Apenas valores de teste, sem credenciais reais

#### 🛡️ Pipeline de Segurança
- **Gosec**: Análise estática de segurança automatizada
- **Dependency Scanning**: Verificação de vulnerabilidades em dependências
- **SARIF Reports**: Relatórios de segurança integrados ao GitHub
- **Security First**: Falha de build em caso de vulnerabilidades críticas

#### 🔒 Comunicação Segura
- **TLS/SMTP**: Comunicação criptografada com Amazon SES (porta 587)
- **AWS IAM**: Credenciais SES com permissões mínimas necessárias
- **Network Policies**: Controle de tráfego de rede no Kubernetes
- **Certificate Validation**: Validação de certificados SSL/TLS

### Configuração de Secrets

#### Kubernetes Secrets (Produção)
```bash
# Criar secret para credenciais SES
kubectl create secret generic ses-email-secrets \
  --from-literal=ses-smtp-username=AKIAIOSFODNN7EXAMPLE \
  --from-literal=ses-smtp-password=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --namespace=fiapx

# Verificar se o secret foi criado
kubectl get secrets -n fiapx | grep ses-email-secrets
```

#### GitHub Secrets (CI/CD)
```bash
# Configurar secrets no GitHub para o pipeline
DOCKER_USERNAME=hmoraes
DOCKER_PASSWORD=<docker-hub-token>
KUBE_CONFIG=<base64-encoded-kubeconfig>
```

### Auditoria de Segurança

#### Checklist de Segurança ✅
- [x] Imagem Docker sem vulnerabilidades conhecidas
- [x] Usuário não-root no container
- [x] Secrets gerenciados pelo Kubernetes
- [x] Comunicação TLS/SSL obrigatória
- [x] Análise estática de código (gosec)
- [x] Dependency scanning automatizado
- [x] Network policies configuradas
- [x] Resource limits definidos
- [x] Health checks implementados
- [x] Logs não contêm informações sensíveis

#### Compliance
- **OWASP Top 10**: Mitigação de vulnerabilidades principais
- **CIS Docker Benchmark**: Conformidade com padrões de segurança
- **NIST Cybersecurity Framework**: Alinhamento com práticas recomendadas
- **SOC 2 Type II**: Preparado para auditoria de segurança

### Monitoramento de Segurança

#### Alertas Configurados
- Falhas de autenticação SMTP
- Tentativas de acesso não autorizado
- Anomalias no volume de emails
- Violações de rate limiting
- Falhas de health check

#### Logs de Segurança
```go
// Exemplos de logs estruturados
log.Info("Email sent successfully", 
  "user_id", userID, 
  "email_hash", hashEmail(email))

log.Error("SMTP authentication failed", 
  "error", err, 
  "smtp_host", smtpHost)
```

## 🚀 Deploy e Operações

### Deploy Automatizado
```bash
# Via Makefile
make k8s-deploy

# Via kubectl direto
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/notification-service -n fiapx
```

### Troubleshooting

#### Verificar Status do Serviço
```bash
# Status dos pods
kubectl get pods -l app=notification-service -n fiapx

# Logs do serviço
kubectl logs -f deployment/notification-service -n fiapx

# Verificar secrets
kubectl get secrets ses-email-secrets -n fiapx -o yaml
```

#### Problemas Comuns

1. **Secret não encontrado**
   ```bash
   Error: secret "ses-email-secrets" not found
   ```
   **Solução**: Criar o secret usando o comando acima

2. **Falha de autenticação SES**
   ```bash
   Error: SMTP authentication failed
   ```
   **Solução**: Verificar credenciais SES e região

3. **Container não inicia**
   ```bash
   Error: container has runAsNonRoot and image will run as root
   ```
   **Solução**: Usar imagem com usuário não-root

### Contribuição

1. Fork do repositório
2. Criar branch para feature (`git checkout -b feature/nova-feature`)
3. Commit das alterações (`git commit -am 'Adiciona nova feature'`)
4. Push para branch (`git push origin feature/nova-feature`)
5. Criar Pull Request

### Suporte

- **Documentação**: [Wiki do Projeto](https://github.com/hqmoraes/projeto-fiapx/wiki)
- **Issues**: [GitHub Issues](https://github.com/hqmoraes/projeto-fiapx/issues)
- **Discussões**: [GitHub Discussions](https://github.com/hqmoraes/projeto-fiapx/discussions)

---

**FIAP-X Notification Service** - Parte da arquitetura de microsserviços para processamento de vídeo em nuvem.
