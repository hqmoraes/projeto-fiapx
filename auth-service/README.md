# Serviço de Autenticação

O `auth-service` é responsável por gerenciar a autenticação de usuários e a emissão de tokens JWT (JSON Web Tokens).

## Funcionalidades

- **Registro de Usuários**: Permite que novos usuários se cadastrem na plataforma.
- **Login de Usuários**: Autentica usuários com base em suas credenciais.
- **Emissão de Tokens JWT**: Gera tokens seguros para autorizar o acesso aos demais microsserviços.
- **Validação de Tokens**: Fornece endpoints para que outros serviços validem a autenticidade dos tokens.

## Execução

Para executar o Serviço de Autenticação localmente, utilize o Docker Compose:

```bash
docker-compose up -d auth-service
```

No ambiente de produção, o deploy é gerenciado pelo workflow de CI/CD do Kubernetes.
