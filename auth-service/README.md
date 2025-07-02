# Auth Service

## Descrição
O Auth Service é o serviço responsável pela autenticação e autorização de usuários na plataforma FiapX. Ele gerencia o registro de usuários, login, verificação de identidade e geração de tokens JWT para acesso aos demais serviços.

## Posição Hierárquica
Este serviço é o mais fundamental na hierarquia do sistema, pois:
1. Todos os outros serviços dependem dele para validação de usuários
2. Não possui dependências de outros serviços da aplicação
3. É necessário estar operacional antes dos outros serviços para garantir segurança

## Funcionalidades
- Registro de novos usuários
- Autenticação de usuários (login)
- Geração e validação de tokens JWT
- Consulta de informações do usuário autenticado

## Endpoints
- `POST /register`: Registro de novos usuários
- `POST /login`: Autenticação de usuários
- `GET /me`: Obtenção de dados do usuário autenticado (requer token JWT)
- `GET /health`: Verificação de saúde do serviço

## Tecnologias Utilizadas
- Go (linguagem de programação)
- PostgreSQL (banco de dados)
- JWT (autenticação)
- Chi Router (framework web)

## Configurações
O serviço pode ser configurado através das seguintes variáveis de ambiente:
- `DB_HOST`: Host do banco de dados PostgreSQL (padrão: postgres)
- `DB_PORT`: Porta do banco de dados PostgreSQL (padrão: 5432)
- `DB_NAME`: Nome do banco de dados (padrão: fiapx_auth)
- `DB_USER`: Usuário do banco de dados (padrão: postgres)
- `DB_PASSWORD`: Senha do banco de dados (padrão: postgres)
- `JWT_SECRET`: Chave secreta para geração de tokens JWT (padrão: secret_change_me)
- `PORT`: Porta em que o serviço irá escutar (padrão: 8081)

## Implantação
Este serviço é implantado no cluster Kubernetes com os seguintes recursos:
- Deployment com 2 réplicas para alta disponibilidade
- Service para comunicação interna
- NetworkPolicy para controle de tráfego
- Secret para armazenamento de credenciais

## Dependências
- PostgreSQL: Armazenamento de dados de usuários

## Segurança
- Senhas armazenadas com hash bcrypt
- Comunicação com outros serviços protegida por JWT
- Limitação de acesso via NetworkPolicy no Kubernetes

## Desenvolvimento Local
Para executar o serviço localmente:

```bash
cd auth-service
go run cmd/auth-service/main.go
```

## Compilação
Para compilar o serviço:

```bash
cd auth-service
go build -o auth-service cmd/auth-service/main.go
```

## Kubernetes
Os manifestos Kubernetes para este serviço estão em `infrastructure/kubernetes/auth-service/`.
# teste direct push
