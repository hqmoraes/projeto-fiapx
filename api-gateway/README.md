# API Gateway

O API Gateway é o ponto de entrada principal para a aplicação de processamento de vídeos FiapX. Ele é responsável por:

- Roteamento de requisições para os serviços apropriados
- Autenticação e autorização via JWT
- Limitação de taxa (rate limiting)
- Configuração de CORS
- Logging e monitoramento básicos

## Estrutura do Serviço

```
api-gateway/
├── cmd/
│   └── api-gateway/
│       └── main.go         # Ponto de entrada da aplicação
├── config/
│   └── config.yaml         # Configurações do serviço
├── pkg/
│   ├── auth/               # Lógica de autenticação
│   ├── middleware/         # Middleware personalizados
│   └── proxy/              # Lógica de encaminhamento para outros serviços
├── Dockerfile              # Instruções para build da imagem Docker
├── go.mod                  # Dependências Go
└── go.sum                  # Checksums das dependências
```

## Endpoints

### Públicos

- `GET /` - Página inicial do API
- `GET /health` - Verificação de saúde do serviço
- `POST /auth/login` - Login de usuário
- `POST /auth/register` - Registro de novo usuário

### Protegidos (requerem JWT)

- `POST /videos/upload` - Upload de um novo vídeo
- `GET /videos` - Listar todos os vídeos do usuário
- `GET /videos/{id}` - Obter detalhes de um vídeo específico

## Configuração

As seguintes variáveis de ambiente podem ser configuradas:

- `PORT` - Porta em que o serviço será executado (padrão: 8080)
- `AUTH_SERVICE_URL` - URL do serviço de autenticação
- `UPLOAD_SERVICE_URL` - URL do serviço de upload
- `STORAGE_SERVICE_URL` - URL do serviço de armazenamento
- `JWT_SECRET` - Chave secreta para assinatura de tokens JWT
- `LOG_LEVEL` - Nível de log (debug, info, warn, error)

## Execução

### Local

```bash
go run cmd/api-gateway/main.go
```

### Docker

```bash
docker build -t fiapx-api-gateway .
docker run -p 8080:8080 fiapx-api-gateway
```

### Kubernetes

```bash
kubectl apply -f kubernetes/api-gateway.yaml
```
