# Serviço de Notificação

O `notification-service` é responsável por enviar notificações por email aos usuários sobre o status do processamento de seus vídeos.

## Funcionalidades

- **Notificações por Email**: Envia emails automáticos quando um vídeo é processado com sucesso ou encontra um erro.
- **Integração com SMTP**: Utiliza um servidor SMTP para o envio dos emails.
- **Templates de Email**: Permite a personalização das mensagens enviadas.

## Execução

Para executar o Serviço de Notificação localmente, utilize o Docker Compose:

```bash
docker-compose up -d notification-service
```

No ambiente de produção, o deploy é gerenciado pelo workflow de CI/CD do Kubernetes.
