### **Relatório Técnico do Projeto FIAP-X: Plataforma de Processamento de Vídeos Baseada em Microsserviços**

**Autor:** Equipe de Desenvolvimento FIAP-X
**Data:** 02 de Julho de 2025
**Versão:** 1.0

---

### **1. Introdução**

Este documento descreve a arquitetura e a implementação do projeto FIAP-X, uma plataforma desenvolvida como solução para o processamento assíncrono de vídeos. O sistema foi concebido para ser modular, escalável e resiliente, utilizando uma arquitetura de microsserviços para segmentar as responsabilidades e facilitar a manutenção e a evolução contínua.

O objetivo principal do projeto é oferecer uma interface para que usuários possam realizar o upload de vídeos, que são então processados em segundo plano para extração de quadros (frames), e posteriormente disponibilizados para download.

---

### **2. Arquitetura da Solução**

A arquitetura do FIAP-X é baseada em um conjunto de microsserviços independentes que se comunicam de forma síncrona (via requisições HTTP) e assíncrona (através de um sistema de mensageria).

O fluxo de operação básico é o seguinte:
1.  O usuário interage com o **Frontend** para se autenticar e realizar o upload de um vídeo.
2.  O **API Gateway** recebe a requisição e a direciona para o **Upload Service**.
3.  O **Upload Service** armazena o vídeo em um storage temporário e publica uma mensagem em uma fila do RabbitMQ, notificando que um novo vídeo precisa ser processado.
4.  O **Processing Service** consome a mensagem da fila, realiza o processamento do vídeo (extração de frames), compacta o resultado e o armazena no MinIO (storage de objetos).
5.  O **Storage Service** gerencia os metadados dos vídeos processados e permite que o usuário liste e baixe os arquivos a partir do **Frontend**.
6.  O **Auth Service** centraliza a autenticação e autorização de usuários, emitindo tokens JWT para acesso seguro aos demais serviços.

---

### **3. Componentes e Microsserviços**

O projeto é composto pelos seguintes repositórios e serviços, cada um com uma responsabilidade única no ecossistema.

#### **3.1. Frontend**
-   **Descrição:** Interface web (Single Page Application) que constitui o ponto de interação do usuário com a plataforma. Permite o login, upload de vídeos, listagem de arquivos processados e download dos resultados.
-   **Repositório:** [https://github.com/hqmoraes/fiapx-frontend](https://github.com/hqmoraes/fiapx-frontend)

#### **3.2. Auth Service**
-   **Descrição:** Microsserviço responsável pela gestão de identidades. Implementa funcionalidades de registro de novos usuários e autenticação baseada em JSON Web Tokens (JWT).
-   **Repositório:** [https://github.com/hqmoraes/fiapx-auth-service](https://github.com/hqmoraes/fiapx-auth-service)

#### **3.3. Upload Service**
-   **Descrição:** Gerencia o processo de upload de vídeos. Recebe os arquivos, valida o formato e o tamanho, e dispara o evento para o início do processamento assíncrono.
-   **Repositório:** [https://github.com/hqmoraes/fiapx-upload-service](https://github.com/hqmoraes/fiapx-upload-service)

#### **3.4. Processing Service**
-   **Descrição:** Núcleo do sistema de processamento. Este serviço consome as tarefas da fila, utiliza a biblioteca `ffmpeg` para extrair os frames do vídeo, compacta os quadros em um arquivo ZIP e os envia para o sistema de armazenamento de objetos.
-   **Repositório:** [https://github.com/hqmoraes/fiapx-processing-service](https://github.com/hqmoraes/fiapx-processing-service)

#### **3.5. Storage Service**
-   **Descrição:** Provê uma API para interagir com os arquivos processados. Permite a listagem dos vídeos disponíveis para um determinado usuário e gerencia o download dos arquivos ZIP a partir do MinIO.
-   **Repositório:** [https://github.com/hqmoraes/fiapx-storage-service](https://github.com/hqmoraes/fiapx-storage-service)

---

### **4. Tecnologias Utilizadas**

-   **Linguagem (Backend):** Go (versão 1.21)
-   **Linguagem (Frontend):** HTML5, CSS3, JavaScript (Vanilla)
-   **Banco de Dados:** PostgreSQL (para armazenamento de metadados e informações de usuários)
-   **Mensageria:** RabbitMQ (para comunicação assíncrona entre os serviços)
-   **Armazenamento de Objetos:** MinIO (para armazenar os vídeos originais e os resultados do processamento)
-   **Containerização:** Docker
-   **Orquestração (Local):** Docker Compose
-   **Monitoramento:** Prometheus (coleta de métricas) e Grafana (visualização e dashboards)

---

### **5. Infraestrutura e Implantação (CI/CD)**

A infraestrutura do projeto foi projetada para ser executada em contêineres Docker, garantindo a portabilidade e a consistência entre os ambientes de desenvolvimento e produção. O arquivo `docker-compose.yml` localizado no diretório `infrastructure/` orquestra a execução de todos os serviços e suas dependências localmente.

Para a automação dos processos de build, teste e deploy, foram implementados workflows de Integração Contínua e Entrega Contínua (CI/CD) utilizando GitHub Actions.

---

### **6. Monitoramento e Observabilidade**

A saúde e a performance do sistema são monitoradas através de um stack composto por Prometheus e Grafana.
-   **Prometheus:** Coleta métricas expostas pelos microsserviços, como uso de CPU e memória, número de requisições HTTP e métricas específicas da aplicação (ex: goroutines em Go).
-   **Grafana:** Utilizado para visualizar as métricas coletadas pelo Prometheus. Dashboards customizados foram criados para fornecer uma visão clara do status de cada serviço, permitindo a identificação rápida de anomalias e gargalos.

---

### **7. Conclusão**

O projeto FIAP-X implementa com sucesso uma plataforma robusta e funcional para processamento de vídeos, seguindo as melhores práticas de desenvolvimento de software, como a arquitetura de microsserviços, containerização e monitoramento. A solução final é escalável, permitindo a evolução futura com a adição de novas funcionalidades ou a otimização dos componentes existentes de forma independente.
