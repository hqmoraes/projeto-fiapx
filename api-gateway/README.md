# API Gateway

O `api-gateway` é o ponto de entrada único para todas as requisições da plataforma FIAP-X. Ele é responsável por rotear o tráfego para os microsserviços apropriados, além de lidar com a autenticação e o balanceamento de carga.

## Funcionalidades

- **Roteamento Inteligente**: Direciona as requisições para os serviços corretos com base na URL.
- **Autenticação Centralizada**: Valida tokens JWT antes de encaminhar as requisições.
- **Balanceamento de Carga**: Distribui o tráfego entre as instâncias dos microsserviços.
- **Segurança**: Atua como uma camada de proteção, expondo apenas os endpoints necessários.

## Execução

Para executar o API Gateway localmente, utilize o Docker Compose:

```bash
docker-compose up -d api-gateway
```

No ambiente de produção, o deploy é gerenciado pelo workflow de CI/CD do Kubernetes.
