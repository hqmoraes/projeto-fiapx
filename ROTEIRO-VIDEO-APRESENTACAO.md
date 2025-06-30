# 🎬 ROTEIRO PARA VÍDEO DE APRESENTAÇÃO
## Projeto FIAP-X - Sistema de Processamento de Vídeos
**Duração Total: 10 minutos | Formato: Demonstração prática**

---

## 📋 ESTRUTURA DO VÍDEO

### 🎯 **ABERTURA (30 segundos)**
```
[TELA]: Logo FIAP-X + Título do Projeto
[NARRAÇÃO]: "Olá! Apresento o projeto FIAP-X, um sistema escalável de 
processamento de vídeos desenvolvido com arquitetura de microsserviços, 
rodando em produção na AWS com observabilidade completa."
```

### 📖 **SEÇÃO 1: DOCUMENTAÇÃO E ARQUITETURA (2 minutos)**

#### 1.1 Visão Geral da Arquitetura (45s)
```
[TELA]: Abrir DOCUMENTACAO-ARQUITETURA.md
[AÇÃO]: Navegar pelo documento mostrando:
- Diagrama de arquitetura
- Microsserviços implementados
- Stack tecnológica

[NARRAÇÃO]: "A arquitetura foi projetada com 5 microsserviços principais: 
Auth Service para autenticação, Upload Service para recebimento de arquivos, 
Processing Service para extração de frames, Storage Service para downloads, 
e API Gateway para orquestração. Tudo rodando em Kubernetes na AWS."
```

#### 1.2 Funcionalidades Implementadas (45s)
```
[TELA]: Mostrar seção "Funcionalidades Essenciais Implementadas"
[AÇÃO]: Destacar checkmarks das funcionalidades

[NARRAÇÃO]: "Todos os requisitos foram implementados: processamento paralelo 
de múltiplos vídeos, sistema que não perde requisições em picos, autenticação 
segura com JWT, listagem de status em tempo real, e sistema de notificação 
de erros com observabilidade completa."
```

#### 1.3 Qualidade e Testes (30s)
```
[TELA]: Mostrar seção "Evidências de Qualidade"
[AÇÃO]: Destacar cobertura de testes 84.6%

[NARRAÇÃO]: "O projeto mantém alta qualidade com 84.6% de cobertura de testes 
distribuída em 45+ cenários, garantindo confiabilidade e manutenibilidade."
```

### 🏗️ **SEÇÃO 2: AMBIENTE E INFRAESTRUTURA (1 minuto 30s)**

#### 2.1 Cluster Kubernetes AWS (45s)
```
[TELA]: Terminal SSH conectado ao servidor AWS
[AÇÃO]: Executar comandos:
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click
kubectl get pods -A

[NARRAÇÃO]: "O sistema roda em um cluster Kubernetes na AWS. Aqui vemos todos 
os pods em execução: nossos microsserviços no namespace fiapx, e o stack de 
monitoramento no namespace monitoring com Prometheus e Grafana."
```

#### 2.2 Validação dos Serviços (45s)
```
[TELA]: Continuar no terminal
[AÇÃO]: Executar:
kubectl get svc -n fiapx
kubectl get hpa -n fiapx

[NARRAÇÃO]: "Todos os serviços estão expostos e o HPA (Horizontal Pod Autoscaler) 
está ativo, pronto para escalar automaticamente baseado no uso de CPU e memória."
```

### 👤 **SEÇÃO 3: DEMONSTRAÇÃO PRÁTICA - CRIAÇÃO DE USUÁRIO (1 minuto)**

#### 3.1 Acesso ao Frontend (30s)
```
[TELA]: Browser abrindo https://api.wecando.click
[AÇÃO]: Navegar para página de cadastro

[NARRAÇÃO]: "Vamos começar criando um usuário. O frontend está rodando com 
HTTPS válido na AWS, integrado com nosso API Gateway."
```

#### 3.2 Registro de Usuário (30s)
```
[TELA]: Formulário de cadastro
[AÇÃO]: Preencher:
- Username: demo_user
- Email: demo@fiapx.com  
- Password: Demo123!
- Clicar "Registrar"

[NARRAÇÃO]: "Criando um novo usuário que será autenticado via JWT token. 
Os dados são persistidos no PostgreSQL com senha criptografada."
```

### 📤 **SEÇÃO 4: UPLOAD E PROCESSAMENTO (2 minutos)**

#### 4.1 Login e Upload de Vídeos (1 minuto)
```
[TELA]: Página de login, depois dashboard
[AÇÃO]: 
1. Fazer login com o usuário criado
2. Navegar para seção de upload
3. Selecionar 2-3 vídeos pequenos (.mp4)
4. Iniciar upload

[NARRAÇÃO]: "Após login, acessamos o dashboard onde podemos fazer upload 
múltiplo de vídeos. O Upload Service valida os arquivos e os armazena no 
MinIO S3-compatible, criando jobs na fila do RabbitMQ."
```

#### 4.2 Acompanhar Status em Tempo Real (1 minuto)
```
[TELA]: Dashboard mostrando lista de jobs
[AÇÃO]: Mostrar jobs mudando de status:
- PENDING → PROCESSING → COMPLETED

[NARRAÇÃO]: "Aqui vemos o processamento em tempo real. O Processing Service 
pega os jobs da fila, extrai os frames usando FFmpeg, e atualiza o status 
via cache Redis. Múltiplos vídeos são processados em paralelo."
```

### 📊 **SEÇÃO 5: OBSERVABILIDADE E MONITORAMENTO (2 minutos)**

#### 5.1 Métricas do Prometheus (45s)
```
[TELA]: Terminal para port-forward + Browser Prometheus
[AÇÃO]: 
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
Abrir http://localhost:9090
Executar query: up{job="processing-service"}

[NARRAÇÃO]: "O Prometheus está coletando métricas dos nossos serviços. 
Aqui vemos que o processing-service está UP e respondendo. Temos métricas 
de CPU, memória, requisições HTTP e métricas específicas do Go."
```

#### 5.2 Dashboards do Grafana (1 minuto 15s)
```
[TELA]: Terminal para port-forward + Browser Grafana
[AÇÃO]:
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
Abrir http://localhost:3000
Login: admin / prom-operator
Mostrar dashboards:
- Kubernetes Cluster Overview
- FIAP-X Processing Service Dashboard

[NARRAÇÃO]: "No Grafana temos visualização completa das métricas. Este 
dashboard customizado mostra CPU, memória, status dos serviços, número de 
goroutines Go, e requests HTTP em tempo real. Perfeito para monitoramento 
de produção e identificação proativa de problemas."
```

### 🔄 **SEÇÃO 6: CI/CD E AUTO-SCALING (1 minuto 30s)**

#### 6.1 Pipeline CI/CD (45s)
```
[TELA]: GitHub Actions - Workflow em execução
[AÇÃO]: Mostrar:
- Pipeline rodando
- Testes executando
- Build e deploy automático

[NARRAÇÃO]: "O CI/CD está totalmente automatizado via GitHub Actions. 
A cada push, roda os testes, faz build das imagens Docker, e deploy 
automático para AWS. Temos quality gates baseados na cobertura de testes."
```

#### 6.2 Horizontal Pod Autoscaler (45s)
```
[TELA]: Terminal + comando de carga
[AÇÕES]:
kubectl get hpa -n fiapx -w
# Em paralelo, simular carga:
kubectl run load-test --image=busybox --rm -it --restart=Never -- /bin/sh
while true; do wget -q -O- http://processing-service.fiapx.svc.cluster.local:8080/health; done

[NARRAÇÃO]: "Para demonstrar a escalabilidade, vou simular carga no sistema. 
O HPA detecta o aumento de CPU/memória e automaticamente cria novos pods 
do processing-service, distribuindo a carga. Isso garante que o sistema 
não perca requisições mesmo em picos de demanda."
```

### 💾 **SEÇÃO 7: DOWNLOAD DOS RESULTADOS (45s)**

#### 7.1 Download do ZIP de Frames (45s)
```
[TELA]: Voltar ao dashboard web
[AÇÃO]: 
- Mostrar jobs COMPLETED
- Clicar "Download" em um job
- Mostrar arquivo ZIP baixando
- Abrir ZIP mostrando frames extraídos

[NARRAÇÃO]: "Quando o processamento termina, o usuário pode baixar um arquivo 
ZIP contendo todos os frames extraídos do vídeo. O Storage Service gera o 
ZIP dinamicamente e gerencia o cleanup automático dos arquivos temporários."
```

### 🎯 **ENCERRAMENTO (30 segundos)**

#### 7.1 Resumo dos Resultados (30s)
```
[TELA]: Voltando à documentação - seção "Resultados Alcançados"
[AÇÃO]: Destacar checkmarks finais

[NARRAÇÃO]: "Concluindo: implementamos um sistema completo e escalável que 
atende todos os requisitos funcionais e técnicos. Temos processamento paralelo, 
arquitetura de microsserviços, observabilidade completa, CI/CD automatizado, 
e alta qualidade com 84.6% de cobertura de testes. O sistema está rodando 
em produção na AWS, pronto para escalar conforme a demanda."

[TELA]: Logo FIAP-X
[NARRAÇÃO]: "Obrigado pela atenção! Este foi o projeto FIAP-X."
```

---

## 📝 CHECKLIST PRÉ-GRAVAÇÃO

### ✅ Ambiente Preparado
- [ ] SSH configurado para AWS
- [ ] Port-forwards testados (Grafana/Prometheus)
- [ ] Browser com abas pré-configuradas
- [ ] Vídeos pequenos para upload (< 10MB cada)
- [ ] Terminal com comandos preparados

### ✅ Comandos Essenciais
```bash
# Conexão AWS
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click

# Status dos pods
kubectl get pods -A | grep -E 'fiapx|monitoring'
kubectl get svc -n fiapx
kubectl get hpa -n fiapx

# Port-forwards (em terminais separados)
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring

# Teste de carga
kubectl run load-test --image=busybox --rm -it --restart=Never -- /bin/sh
# Dentro do pod:
while true; do wget -q -O- http://processing-service.fiapx.svc.cluster.local:8080/health; done

# Monitor HPA
kubectl get hpa -n fiapx -w
```

### ✅ URLs Importantes
- **Frontend:** https://api.wecando.click
- **Grafana:** http://localhost:3000 (admin/prom-operator)
- **Prometheus:** http://localhost:9090
- **GitHub:** [Link do repositório]

### ✅ Dados para Demonstração
```
Usuário de teste:
- Username: demo_user
- Email: demo@fiapx.com
- Password: Demo123!

Queries Prometheus:
- up{job="processing-service"}
- rate(container_cpu_usage_seconds_total{namespace="fiapx"}[5m])
- go_goroutines{job="processing-service"}
```

---

## 🎨 DICAS DE GRAVAÇÃO

### 📹 Aspectos Técnicos
- **Resolução:** 1080p mínimo
- **Frame Rate:** 30fps
- **Audio:** Clear narration, sem ruído de fundo
- **Screen Recording:** OBS Studio ou similar

### 🎤 Narração
- **Tom:** Profissional, confiante, didático
- **Velocidade:** Moderada, permitindo acompanhar as ações
- **Pausas:** Entre seções para respirar

### ⏱️ Timing
- **Total:** Máximo 10 minutos
- **Buffer:** Manter 30s de margem
- **Transições:** Suaves entre seções

### 🔄 Contingências
- **Plano B:** Se algo falhar, ter screenshots preparados
- **Backup:** Ter ambiente local docker-compose funcionando
- **Scripts:** Comandos salvos para execução rápida

---

**📅 Data Limite:** [Inserir data de entrega]  
**👨‍🎬 Responsável:** [Nome do apresentador]  
**✅ Status:** Roteiro pronto para execução
