# Arquitetura de Microsserviços para Processamento de Vídeos

## Visão Geral
A arquitetura proposta refatora a aplicação monolítica atual em uma solução baseada em microsserviços, implementando os princípios de arquitetura moderna mencionados nas diretrizes. Esta arquitetura resolve os problemas de escalabilidade, segurança e manutenção da aplicação atual.

## Componentes Principais

### 1. Camada de Entrada e Segurança
- **API Gateway / Ingress**: Ponto de entrada único para todas as requisições, oferecendo roteamento, load balancing e rate limiting.
- **Serviço de Autenticação**: Responsável por autenticar usuários e gerar tokens JWT para autorização das operações.

### 2. Microsserviços Core
- **Serviço de Upload**: API REST que recebe os arquivos de vídeo dos usuários, valida formatos e envia para processamento.
- **Serviço de Processamento**: Responsável por executar as operações de processamento de vídeo (conversão, compressão, etc.)
- **Serviço de Armazenamento**: Gerencia o armazenamento e recuperação dos vídeos processados.

### 3. Mensageria
- **RabbitMQ**: Sistema de mensageria para comunicação assíncrona entre os serviços, garantindo desacoplamento e resiliência.

### 4. Persistência de Dados
- **PostgreSQL**: Banco de dados relacional para armazenar metadados dos vídeos, informações de usuários e configurações.
- **Redis**: Cache distribuído para armazenar informações temporárias e estados de processamento.
- **MinIO/S3**: Armazenamento de objetos para os arquivos de vídeo originais e processados.

### 5. Monitoramento e Observabilidade
- **Prometheus & Grafana**: Coleta de métricas e visualização para monitoramento de performance.
- **Stack ELK**: Centralização de logs para análise e troubleshooting.

### 6. CI/CD
- **Pipeline de CI/CD**: Automação para build, teste e deploy dos microsserviços, utilizando GitHub Actions ou Jenkins.

### 7. Infraestrutura
- **Kubernetes**: Orquestração dos containers, oferecendo alta disponibilidade, escalabilidade e autorrecuperação.

## Fluxo de Dados

1. O usuário se autentica através do Serviço de Autenticação e recebe um token JWT.
2. O upload de vídeo é feito através do API Gateway, que valida o token e encaminha a requisição para o Serviço de Upload.
3. O Serviço de Upload valida o arquivo, salva temporariamente e publica uma mensagem no RabbitMQ.
4. O Serviço de Processamento consome a mensagem da fila, processa o vídeo e publica o resultado em outra fila.
5. O Serviço de Armazenamento armazena o vídeo processado no MinIO/S3 e atualiza os metadados no PostgreSQL.
6. O usuário pode verificar o status do processamento e acessar o vídeo processado através do API Gateway.

## Benefícios da Arquitetura

- **Escalabilidade**: Componentes individuais podem ser escalados independentemente conforme a demanda.
- **Resiliência**: Falhas em um serviço não afetam todo o sistema.
- **Manutenibilidade**: Facilidade para evoluir e manter cada componente separadamente.
- **Segurança**: Autenticação centralizada e comunicação segura entre serviços.
- **Observabilidade**: Monitoramento completo da aplicação e infraestrutura.
- **Agilidade**: Implantação contínua e independente de novas funcionalidades.

## Como Implementar

1. Divida o código monolítico em serviços conforme as responsabilidades descritas acima.
2. Implemente a comunicação assíncrona usando RabbitMQ.
3. Configure a persistência de dados em PostgreSQL e MinIO/S3.
4. Containerize cada serviço usando Docker.
5. Configure o cluster Kubernetes e implante os serviços.
6. Implemente o pipeline de CI/CD para automação.
7. Configure o monitoramento e observabilidade.

Este diagrama e documentação fornecem um guia para a implementação da arquitetura proposta, atendendo às diretrizes de modernização da aplicação.
