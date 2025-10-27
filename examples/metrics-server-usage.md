# Kubernetes Metrics Server Usage Guide

This guide explains how to use the Kubernetes Metrics Server for resource monitoring and autoscaling in your EKS cluster.

## Overview

The Metrics Server is a scalable, efficient source of container resource metrics for Kubernetes built-in autoscaling pipelines. It collects resource metrics from Kubelets and exposes them in Kubernetes apiserver through Metrics API for use by:

- Horizontal Pod Autoscaler (HPA)
- Vertical Pod Autoscaler (VPA)
- `kubectl top` commands
- Custom monitoring solutions

## Deployment

### Using GitLab CI/CD

1. **Deploy via Pipeline**:
   ```bash
   # Deploy to dev
   Trigger: deploy:metrics-server:dev
   
   # Deploy to prod
   Trigger: deploy:metrics-server:prod
   ```

2. **Control via Variables**:
   ```bash
   # Enable installation
   INSTALL_METRICS_SERVER=true
   
   # Disable installation
   INSTALL_METRICS_SERVER=false
   ```

### Manual Deployment

```bash
# Update dependencies
helm dependency update charts/metrics-server

# Deploy to dev
helm upgrade --install metrics-server charts/metrics-server \
  -n kube-system --create-namespace \
  -f charts/metrics-server/values-dev.yaml

# Deploy to prod
helm upgrade --install metrics-server charts/metrics-server \
  -n kube-system --create-namespace \
  -f charts/metrics-server/values-prod.yaml
```

## Verification

### 1. Check Pod Status

```bash
# Check if metrics-server pod is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server
```

### 2. Test Metrics API

```bash
# Check if metrics API is available
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# Test node metrics
kubectl top nodes

# Test pod metrics
kubectl top pods --all-namespaces
```

### 3. Verify API Registration

```bash
# Check metrics API registration
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .

# Check pod metrics endpoint
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq .
```

## Usage Examples

### 1. Horizontal Pod Autoscaler (HPA)

Create an HPA that scales based on CPU utilization:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

### 2. Vertical Pod Autoscaler (VPA)

Create a VPA for automatic resource recommendations:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
  namespace: default
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode: "Auto"  # or "Off" for recommendations only
  resourcePolicy:
    containerPolicies:
    - containerName: webapp
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 2Gi
      controlledResources: ["cpu", "memory"]
```

### 3. Custom Metrics Monitoring

Query metrics programmatically:

```bash
# Get node metrics
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.items[] | {name: .metadata.name, cpu: .usage.cpu, memory: .usage.memory}'

# Get pod metrics for a namespace
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/default/pods" | jq '.items[] | {name: .metadata.name, cpu: .usage.cpu, memory: .usage.memory}'

# Get specific pod metrics
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/default/pods/webapp-pod" | jq .
```

## Monitoring and Alerting

### 1. Prometheus Integration

If you have Prometheus installed, metrics-server metrics are automatically scraped:

```yaml
# ServiceMonitor for metrics-server (enabled in prod values)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: metrics-server
  endpoints:
  - port: https
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
    interval: 30s
```

### 2. Key Metrics to Monitor

- `metrics_server_manager_tick_duration_seconds` - Processing time
- `metrics_server_kubelet_request_duration_seconds` - Kubelet response time
- `metrics_server_kubelet_request_total` - Request count and status
- `process_resident_memory_bytes` - Memory usage
- `process_cpu_seconds_total` - CPU usage

### 3. Alerting Rules

```yaml
groups:
- name: metrics-server
  rules:
  - alert: MetricsServerDown
    expr: up{job="metrics-server"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Metrics Server is down"
      description: "Metrics Server has been down for more than 5 minutes"

  - alert: MetricsServerHighLatency
    expr: histogram_quantile(0.99, rate(metrics_server_manager_tick_duration_seconds_bucket[5m])) > 0.1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Metrics Server high latency"
      description: "Metrics Server 99th percentile latency is {{ $value }}s"
```

## Troubleshooting

### Common Issues

1. **Metrics not available**:
   ```bash
   # Check if metrics-server is running
   kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server
   
   # Check API service status
   kubectl get apiservice v1beta1.metrics.k8s.io
   
   # Check logs for errors
   kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server
   ```

2. **TLS certificate errors**:
   ```bash
   # For dev environments, you might need to add --kubelet-insecure-tls
   # This is already configured in dev values
   
   # Check kubelet certificate configuration
   kubectl describe node | grep -A 5 "Addresses"
   ```

3. **High resource usage**:
   ```bash
   # Check metrics-server resource usage
   kubectl top pods -n kube-system -l app.kubernetes.io/name=metrics-server
   
   # Adjust resources in values file if needed
   ```

### Debug Commands

```bash
# Check metrics-server configuration
kubectl describe deployment metrics-server -n kube-system

# Check service account and RBAC
kubectl describe sa metrics-server -n kube-system
kubectl describe clusterrole system:metrics-server

# Test direct kubelet connection
kubectl get --raw "/api/v1/nodes/NODE_NAME/proxy/stats/summary"

# Check API service registration
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
```

## Performance Tuning

### 1. Metric Resolution

Adjust collection frequency based on your needs:

```yaml
args:
  - --metric-resolution=15s  # Default: 60s, Min: 10s
```

### 2. Resource Limits

Scale resources based on cluster size:

```yaml
# For clusters with 100+ nodes
resources:
  requests:
    cpu: 200m
    memory: 400Mi
  limits:
    cpu: 500m
    memory: 800Mi
```

### 3. High Availability

For production clusters, run multiple replicas:

```yaml
replicas: 2
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: metrics-server
      topologyKey: kubernetes.io/hostname
```

## Best Practices

1. **Resource Requests**: Always set resource requests on your workloads for accurate HPA scaling
2. **Monitoring**: Monitor metrics-server health and performance
3. **Security**: Use proper TLS configuration in production
4. **Scaling**: Adjust metrics-server resources based on cluster size
5. **Backup**: Consider metrics-server as critical infrastructure

The Metrics Server provides essential resource metrics for Kubernetes autoscaling and monitoring, enabling efficient resource utilization and automatic scaling of your workloads.