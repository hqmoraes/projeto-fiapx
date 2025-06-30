# 🎯 Guia de Evidências Visuais - Observabilidade AWS
## Projeto FIAP-X - Sistema de Processamento de Vídeos

### 📊 **Screenshots Necessários para Evidências**

#### **1. Dashboards Grafana**
- **CPU e Memory Usage** dos pods processing-service
- **HTTP Request Rate** e latência (p95, p50)
- **Goroutines** e conexões de banco
- **Status dos pods** em tempo real
- **HPA (Horizontal Pod Autoscaler)** em ação

#### **2. Prometheus Metrics**
- **Targets** mostrando processing-service sendo coletado
- **Queries** personalizadas funcionando
- **Alertas** configurados (se houver)

#### **3. Kubernetes Dashboard**
- **Pods** rodando no namespace `fiapx`
- **Services** e **Deployments** ativos
- **HPA** escalando automaticamente
- **Logs** dos pods mostrando atividade

### 🎥 **Cenários para Demonstração**

#### **A. Teste de Carga**
1. Fazer upload de múltiplos vídeos simultaneamente
2. Mostrar HPA escalando de 1 para 5 pods
3. Evidenciar distribuição de carga entre pods
4. Demonstrar Redis cache melhorando performance

#### **B. Monitoramento em Tempo Real**
1. Dashboard mostrando métricas em tempo real
2. CPU/Memory usage durante processamento
3. Request rate e latência das APIs
4. Status de saúde dos componentes

#### **C. Recuperação de Falhas**
1. Simular falha de um pod
2. Mostrar Kubernetes reiniciando automaticamente
3. Evidenciar que o serviço continua funcionando
4. Demonstrar alertas funcionando

### 📈 **Queries Prometheus Importantes**

```promql
# CPU Usage por pod
rate(container_cpu_usage_seconds_total{pod=~"processing-service.*"}[5m]) * 100

# Memory Usage
container_memory_usage_bytes{pod=~"processing-service.*"} / 1024 / 1024

# HTTP Request Rate
rate(http_requests_total{job="processing-service"}[5m])

# Request Duration (p95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="processing-service"}[5m]))

# Pods Running
kube_pod_status_phase{pod=~"processing-service.*", phase="Running"}

# HPA Replicas
kube_horizontalpodautoscaler_status_current_replicas{horizontalpodautoscaler="processing-service-hpa"}
```

### 🎪 **Comandos para Coleta de Evidências**

```bash
# 1. Status dos pods
kubectl get pods -n fiapx -o wide

# 2. Status do HPA
kubectl get hpa -n fiapx

# 3. Logs do processing-service
kubectl logs -f deployment/processing-service -n fiapx

# 4. Métricas via curl
kubectl port-forward svc/processing-service 8080:8080 -n fiapx &
curl http://localhost:8080/metrics

# 5. Status dos services
kubectl get svc -n fiapx

# 6. Eventos do cluster
kubectl get events -n fiapx --sort-by='.lastTimestamp'
```

### 📸 **Lista de Screenshots Recomendados**

1. **Grafana Dashboard** - Visão geral com todos os painéis
2. **CPU/Memory Graphs** - Durante processamento de vídeo
3. **Request Rate** - Picos durante uploads múltiplos
4. **HPA Scaling** - Pods escalando de 1 para 5
5. **Prometheus Targets** - Todos os services sendo monitorados
6. **Kubernetes Pods** - Status Running de todos os componentes
7. **Logs Estruturados** - Processing-service processando vídeos
8. **Cache Redis** - Hit rate e performance
9. **Queue RabbitMQ** - Fila de processamento
10. **Frontend Interface** - Upload múltiplo funcionando

### 🎯 **Evidências de Qualidade Enterprise**

- **24 testes** automatizados passando
- **Cobertura** >80% validada
- **CI/CD Pipeline** configurado
- **Observabilidade** completa (Prometheus + Grafana)
- **Escalabilidade** automática (HPA)
- **Alta disponibilidade** (anti-affinity, probes)
- **Cache** otimizado (Redis)
- **Segurança** (NetworkPolicies, resource limits)

### 📋 **Checklist de Evidências**

- [ ] Dashboard Grafana funcionando
- [ ] Prometheus coletando métricas
- [ ] HPA escalando automaticamente
- [ ] Testes passando (24/24)
- [ ] Upload múltiplo funcionando
- [ ] Cache Redis ativo
- [ ] Logs estruturados
- [ ] Performance otimizada
- [ ] Sistema enterprise-ready

---
*Este guia garante evidências visuais completas para demonstração de uma solução enterprise-grade.*
