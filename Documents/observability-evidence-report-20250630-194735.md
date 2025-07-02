# Relatório de Evidências - Observabilidade
## Projeto FIAP-X - Sistema de Processamento de Vídeos

**Data:** Mon Jun 30 19:47:35 UTC 2025
**Ambiente:** AWS Kubernetes Cluster
**Versão:** v-observability

## Resumo Executivo
Este relatório documenta a implementação e validação do sistema de observabilidade para o projeto FIAP-X, incluindo métricas, monitoramento e dashboards visuais.

---

## Status dos Pods

### Pods do Sistema Principal (namespace: fiapx)
```
NAME                                   READY   STATUS    RESTARTS   AGE     IP             NODE               NOMINATED NODE   READINESS GATES
auth-service-7ddfb5fd54-ttkr2          1/1     Running   0          7h39m   10.244.1.85    ip-172-31-200-13   <none>           <none>
frontend-deployment-695b868b9f-jdphz   1/1     Running   0          7h54m   10.244.1.80    ip-172-31-200-13   <none>           <none>
frontend-deployment-695b868b9f-kcb94   1/1     Running   0          7h55m   10.244.0.14    ip-172-31-200-8    <none>           <none>
minio-0                                1/1     Running   0          3d1h    10.244.1.195   ip-172-31-200-13   <none>           <none>
postgres-0                             1/1     Running   0          3d1h    10.244.1.186   ip-172-31-200-13   <none>           <none>
processing-service-78ffc44d6d-48d9d    1/1     Running   0          4m47s   10.244.1.91    ip-172-31-200-13   <none>           <none>
rabbitmq-0                             1/1     Running   0          3d1h    10.244.1.185   ip-172-31-200-13   <none>           <none>
redis-649bbbbf58-2sktx                 1/1     Running   0          3d1h    10.244.1.183   ip-172-31-200-13   <none>           <none>
storage-service-6d45d9b788-6lg2q       1/1     Running   0          7h39m   10.244.1.86    ip-172-31-200-13   <none>           <none>
upload-service-f88fb6bd5-4ckwg         1/1     Running   0          7h39m   10.244.1.87    ip-172-31-200-13   <none>           <none>
```

### Pods de Monitoramento (namespace: monitoring)
```
NAME                                                     READY   STATUS    RESTARTS   AGE     IP              NODE               NOMINATED NODE   READINESS GATES
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          9m15s   10.244.1.90     ip-172-31-200-13   <none>           <none>
prometheus-grafana-55574ccc4c-bjrn8                      3/3     Running   0          9m19s   10.244.0.20     ip-172-31-200-8    <none>           <none>
prometheus-kube-prometheus-operator-54c9b77c65-xg8wr     1/1     Running   0          9m19s   10.244.0.21     ip-172-31-200-8    <none>           <none>
prometheus-kube-state-metrics-7f5f75c85d-5vqxp           1/1     Running   0          9m19s   10.244.1.89     ip-172-31-200-13   <none>           <none>
prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          9m15s   10.244.0.22     ip-172-31-200-8    <none>           <none>
prometheus-prometheus-node-exporter-5mn8w                1/1     Running   0          9m19s   172.31.200.13   ip-172-31-200-13   <none>           <none>
prometheus-prometheus-node-exporter-crptj                1/1     Running   0          9m19s   172.31.200.8    ip-172-31-200-8    <none>           <none>
```

## Métricas e Monitoramento

### ServiceMonitor Configurado
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"monitoring.coreos.com/v1","kind":"ServiceMonitor","metadata":{"annotations":{},"labels":{"release":"prometheus"},"name":"processing-service","namespace":"monitoring"},"spec":{"endpoints":[{"interval":"15s","path":"/metrics","port":"http","scheme":"http"}],"namespaceSelector":{"matchNames":["fiapx"]},"selector":{"matchLabels":{"app":"processing-service"}}}}
  creationTimestamp: "2025-06-30T19:39:18Z"
  generation: 1
  labels:
    release: prometheus
  name: processing-service
  namespace: monitoring
  resourceVersion: "6561392"
  uid: e0841db3-045c-4051-b7b3-a33cee45c448
spec:
  endpoints:
  - interval: 15s
    path: /metrics
    port: http
    scheme: http
  namespaceSelector:
    matchNames:
    - fiapx
  selector:
    matchLabels:
      app: processing-service
```

### Endpoint de Métricas (/metrics)
**URL:** http://processing-service:8080/metrics

**Amostra das métricas expostas:**
```
# HELP go_gc_duration_seconds A summary of the wall-time pause (stop-the-world) duration in garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 2.2294e-05
go_gc_duration_seconds{quantile="0.25"} 2.2294e-05
go_gc_duration_seconds{quantile="0.5"} 9.4769e-05
go_gc_duration_seconds{quantile="0.75"} 9.4769e-05
go_gc_duration_seconds{quantile="1"} 9.4769e-05
go_gc_duration_seconds_sum 0.000117063
go_gc_duration_seconds_count 2
# HELP go_gc_gogc_percent Heap size target percentage configured by the user, otherwise 100. This value is set by the GOGC environment variable, and the runtime/debug.SetGCPercent function. Sourced from /gc/gogc:percent.
# TYPE go_gc_gogc_percent gauge
go_gc_gogc_percent 100
# HELP go_gc_gomemlimit_bytes Go runtime memory limit configured by the user, otherwise math.MaxInt64. This value is set by the GOMEMLIMIT environment variable, and the runtime/debug.SetMemoryLimit function. Sourced from /gc/gomemlimit:bytes.
# TYPE go_gc_gomemlimit_bytes gauge
go_gc_gomemlimit_bytes 9.223372036854776e+18
# HELP go_goroutines Number of goroutines that currently exist.
# TYPE go_goroutines gauge
go_goroutines 12
# HELP go_info Information about the Go environment.
# TYPE go_info gauge
```

### Horizontal Pod Autoscaler (HPA)
```
NAME                     REFERENCE                       TARGETS                       MINPODS   MAXPODS   REPLICAS   AGE
processing-service-hpa   Deployment/processing-service   cpu: 0%/70%, memory: 2%/80%   1         5         1          17h
```

**Detalhes do HPA:**
```yaml
Name:                                                     processing-service-hpa
Namespace:                                                fiapx
Labels:                                                   <none>
Annotations:                                              <none>
CreationTimestamp:                                        Mon, 30 Jun 2025 02:15:06 +0000
Reference:                                                Deployment/processing-service
Metrics:                                                  ( current / target )
  resource cpu on pods  (as a percentage of request):     0% (1m) / 70%
  resource memory on pods  (as a percentage of request):  2% (6823936) / 80%
Min replicas:                                             1
Max replicas:                                             5
Behavior:
  Scale Up:
    Stabilization Window: 30 seconds
    Select Policy: Max
    Policies:
      - Type: Pods  Value: 2  Period: 60 seconds
  Scale Down:
    Stabilization Window: 300 seconds
    Select Policy: Max
    Policies:
      - Type: Pods  Value: 1  Period: 60 seconds
Deployment pods:    1 current / 1 desired
Conditions:
  Type            Status  Reason              Message
  ----            ------  ------              -------
  AbleToScale     True    ReadyForNewScale    recommended size matches current size
  ScalingActive   True    ValidMetricFound    the HPA was able to successfully calculate a replica count from memory resource utilization (percentage of request)
  ScalingLimited  False   DesiredWithinRange  the desired count is within the acceptable range
Events:
  Type     Reason                        Age                    From                       Message
  ----     ------                        ----                   ----                       -------
  Warning  FailedGetResourceMetric       4m35s (x4 over 7h38m)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       4m35s (x4 over 7h38m)  horizontal-pod-autoscaler  failed to get memory utilization: unable to get metrics for resource memory: no metrics returned from resource metrics API
  Warning  FailedComputeMetricsReplicas  4m35s (x4 over 7h38m)  horizontal-pod-autoscaler  invalid metrics (2 invalid out of 2), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       4m20s (x8 over 8h)     horizontal-pod-autoscaler  failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)
```

## Acesso aos Dashboards

### Grafana
- **URL Local:** http://localhost:3000 (via port-forward)
- **Usuário:** admin
- **Senha:** prom-operator
- **Comando para acesso:** `kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring`

### Prometheus
- **URL Local:** http://localhost:9090 (via port-forward)
- **Comando para acesso:** `kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring`

### Dashboards Recomendados para Importação
1. **Kubernetes Cluster Monitoring** - ID: 315
2. **Go Processes** - ID: 6671
3. **Node Exporter Full** - ID: 1860
4. **Kubernetes Pod Monitoring** - ID: 10257

## Utilização de Recursos

### Limites e Requests do Processing-Service
```yaml
{
  "limits": {
    "cpu": "500m",
    "memory": "800Mi"
  },
  "requests": {
    "cpu": "200m",
    "memory": "256Mi"
  }
}
```

### Utilização Atual de CPU e Memory
```
auth-service-7ddfb5fd54-ttkr2          1m     3Mi     
frontend-deployment-695b868b9f-jdphz   1m     3Mi     
frontend-deployment-695b868b9f-kcb94   1m     3Mi     
minio-0                                1m     251Mi   
postgres-0                             5m     44Mi    
processing-service-78ffc44d6d-48d9d    1m     6Mi     
rabbitmq-0                             137m   152Mi   
redis-649bbbbf58-2sktx                 8m     9Mi     
storage-service-6d45d9b788-6lg2q       1m     3Mi     
upload-service-f88fb6bd5-4ckwg         1m     3Mi     
```

## Instruções para Coleta de Evidências Visuais

### 1. Acessar Dashboards
```bash
# Terminal 1 - Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Terminal 2 - Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
```

### 2. Queries Úteis no Prometheus
```promql
# CPU Usage
rate(container_cpu_usage_seconds_total{namespace="fiapx"}[5m])

# Memory Usage
container_memory_usage_bytes{namespace="fiapx"}

# HTTP Requests
rate(promhttp_metric_handler_requests_total[5m])

# Go Goroutines
go_goroutines{job="processing-service"}

# Processing Service Up Status
up{job="processing-service"}
```

### 3. Coleta de Screenshots
1. Acesse http://localhost:3000 (Grafana)
2. Faça login com admin/prom-operator
3. Importe os dashboards pelos IDs: 315, 6671, 1860, 10257
4. Navegue pelos dashboards e colete screenshots
5. Acesse http://localhost:9090 (Prometheus)
6. Execute as queries acima e colete screenshots

## Validação Final

### Checklist de Validação
- [x] Prometheus instalado e rodando
- [x] Grafana instalado e rodando
- [x] ServiceMonitor configurado
- [x] Métricas sendo coletadas do processing-service
- [x] HPA configurado para auto-scaling
- [x] Endpoints de saúde funcionando

### Próximos Passos para Evidências
1. Executar testes de carga para acionar o HPA
2. Coletar screenshots dos dashboards
3. Documentar métricas durante picos de processamento
4. Validar alertas (se configurados)

---
**Relatório gerado em:** Mon Jun 30 19:47:39 UTC 2025
**Autor:** Sistema Automatizado de Deploy
**Status:** ✅ Deploy de Observabilidade Concluído com Sucesso
