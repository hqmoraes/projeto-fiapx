# Repositórios FIAP-X

Repositórios Git criados para o projeto FIAP-X de processamento de vídeos.

## 📁 Repositórios dos Microsserviços

### 1. Auth Service
- **Repositório**: https://github.com/hqmoraes/fiapx-auth-service
- **Descrição**: Microsserviço de autenticação
- **Versão**: v1.2
- **Funcionalidades**: 
  - Registro de usuários
  - Login com JWT
  - Geração automática de usernames válidos

### 2. Upload Service  
- **Repositório**: https://github.com/hqmoraes/fiapx-upload-service
- **Descrição**: Microsserviço de upload de vídeos
- **Versão**: v1.4
- **Funcionalidades**:
  - Upload de vídeos (múltiplos formatos)
  - Validação de tamanho e tipo MIME
  - Integração com MinIO e RabbitMQ

### 3. Processing Service
- **Repositório**: https://github.com/hqmoraes/fiapx-processing-service  
- **Descrição**: Microsserviço de processamento de vídeos
- **Versão**: v2.0
- **Funcionalidades**:
  - Extração real de frames com ffmpeg
  - Criação de ZIP com frames PNG
  - Upload de arquivos processados para MinIO

### 4. Storage Service
- **Repositório**: https://github.com/hqmoraes/fiapx-storage-service
- **Descrição**: Microsserviço de armazenamento e download
- **Versão**: v2.4  
- **Funcionalidades**:
  - Listagem de vídeos processados
  - Download real de ZIP do MinIO
  - Estatísticas de usuário
  - Suporte a filename original

### 5. Frontend
- **Repositório**: https://github.com/hqmoraes/fiapx-frontend
- **Descrição**: Interface web SPA
- **Versão**: v2.3
- **Funcionalidades**:
  - Dashboard responsivo
  - Upload drag-and-drop
  - Listagem e estatísticas
  - Download de arquivos processados

## 🔧 Tecnologias

- **Backend**: Go 1.21, PostgreSQL, MinIO, RabbitMQ
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Infraestrutura**: Docker, Kubernetes, ARM64
- **Deploy**: AWS, Docker Hub

## 🚀 Status do Projeto

✅ **Sistema 100% funcional**
- Extração real de frames implementada
- Download de ZIP com frames PNG
- Exibição correta de nomes de arquivo
- Todos os microsserviços em repositórios separados

## 📝 Próximos Passos

1. **CI/CD**: Implementar GitHub Actions
2. **Monitoramento**: Prometheus + Grafana  
3. **Segurança**: HTTPS obrigatório, validações
4. **Escalabilidade**: Horizontal Pod Autoscaler

## 🔑 Credenciais

- **GitHub User**: hqmoraes
- **Docker Hub**: hmoraes
- **Token**: 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

Todos os repositórios estão configurados com acesso via token para facilitar CI/CD.
