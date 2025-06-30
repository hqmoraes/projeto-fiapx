# Notification Service

## Descrição

O Notification Service é responsável pelo envio de notificações por email para usuários da plataforma FIAP-X. Ele monitora eventos de processamento de vídeos e envia emails automáticos informando sobre o status das operações (sucesso, erro, processamento).

## Tecnologias

- **Linguagem**: Go 1.22+
- **Messaging**: RabbitMQ (AMQP)
- **Email**: SMTP (Gmail/Google Workspace)
- **Templates**: HTML com Go Templates
- **Containerização**: Docker

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

### Implementações
- ✅ SMTP over TLS (porta 587)
- ✅ App Passwords do Google
- ✅ Secrets do Kubernetes para credenciais
- ✅ Sanitização de conteúdo de email
- ✅ Rate limiting implícito via RabbitMQ

### Recomendações
- Usar OAuth2 em vez de senha para maior segurança
- Implementar criptografia de emails sensíveis
- Configurar SPF/DKIM/DMARC no domínio
- Monitorar bounce rate e reputation

## Performance

### Otimizações
- Pool de conexões SMTP reutilizáveis
- Templates pré-compilados em memória
- Batch processing para múltiplos emails
- Retry exponential backoff

### Limites
- **Gmail**: 500 emails/dia (conta gratuita)
- **Google Workspace**: 2000 emails/dia
- **Concorrência**: 1 email por vez (configurável)
- **Timeout**: 30 segundos por email

## Roadmap

### Próximas Funcionalidades
- [ ] Múltiplos provedores SMTP (fallback)
- [ ] Templates dinâmicos via banco de dados
- [ ] Suporte a anexos
- [ ] Webhooks para delivery status
- [ ] Interface web para gestão de templates

### Melhorias Técnicas
- [ ] OAuth2 para Gmail
- [ ] Métricas Prometheus
- [ ] Cache de templates
- [ ] Bulk email processing
- [ ] Email validation

---

## Contato

- **Projeto**: FIAP-X - Video Processing Platform
- **Documentação**: Ver `DOCUMENTACAO-ARQUITETURA.md` na raiz do projeto
- **Email Config**: `scripts/setup-email-notifications.sh`
