# AWS Cluster Autoscaler Setup Guide

This guide explains how to configure and use the AWS Cluster Autoscaler with your EKS cluster.

## Prerequisites

### 1. Auto Scaling Group Tags

Your EKS node groups' Auto Scaling Groups must have the following tags:

```bash
# Required tags for auto-discovery
k8s.io/cluster-autoscaler/enabled=true
k8s.io/cluster-autoscaler/YOUR_CLUSTER_NAME=owned

# Optional tags for better organization
k8s.io/cluster-autoscaler/node-template/label/node-type=worker
k8s.io/cluster-autoscaler/node-template/taint/dedicated=worker:NoSchedule
```

### 2. Node Group Configuration

Ensure your node groups are configured properly:

```bash
# Example using eksctl
eksctl create nodegroup \
  --cluster=my-cluster \
  --name=worker-nodes \
  --node-type=m5.large \
  --nodes=2 \
  --nodes-min=1 \
  --nodes-max=10 \
  --node-ami=auto \
  --asg-access \
  --tags="k8s.io/cluster-autoscaler/enabled=true,k8s.io/cluster-autoscaler/my-cluster=owned"
```

## Configuration

### 1. Update Helm Values

Update your `values-{env}.yaml` files with your cluster name:

```yaml
# charts/cluster-autoscaler/values-dev.yaml
autoDiscovery:
  clusterName: "my-dev-cluster"  # Replace with your actual cluster name

extraArgs:
  node-group-auto-discovery: asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-dev-cluster
```

### 2. IAM Role Configuration

The Terraform configuration automatically creates the necessary IAM role with these permissions:

- `autoscaling:DescribeAutoScalingGroups`
- `autoscaling:DescribeAutoScalingInstances`
- `autoscaling:SetDesiredCapacity`
- `autoscaling:TerminateInstanceInAutoScalingGroup`
- `ec2:DescribeImages`
- `ec2:DescribeInstanceTypes`
- `eks:DescribeNodegroup`

## Deployment

### Using GitLab CI/CD

1. **Deploy via Pipeline**:
   ```bash
   # Deploy to dev
   Trigger: deploy:cluster-autoscaler:dev
   
   # Deploy to prod
   Trigger: deploy:cluster-autoscaler:prod
   ```

2. **Control via Variables**:
   ```bash
   # Enable installation
   INSTALL_CLUSTER_AUTOSCALER=true
   
   # Disable installation
   INSTALL_CLUSTER_AUTOSCALER=false
   ```

### Manual Deployment

```bash
# Update dependencies
helm dependency update charts/cluster-autoscaler

# Deploy to dev
helm upgrade --install cluster-autoscaler charts/cluster-autoscaler \
  -n kube-system --create-namespace \
  -f charts/cluster-autoscaler/values-dev.yaml

# Deploy to prod
helm upgrade --install cluster-autoscaler charts/cluster-autoscaler \
  -n kube-system --create-namespace \
  -f charts/cluster-autoscaler/values-prod.yaml
```

## Verification

### 1. Check Pod Status

```bash
# Check if cluster-autoscaler pod is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler
```

### 2. Test Scaling

Create a test deployment to trigger scaling:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale-test
spec:
  replicas: 10
  selector:
    matchLabels:
      app: scale-test
  template:
    metadata:
      labels:
        app: scale-test
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
```

```bash
# Apply the test deployment
kubectl apply -f scale-test.yaml

# Watch nodes being added
kubectl get nodes -w

# Check cluster-autoscaler events
kubectl get events -n kube-system --field-selector reason=TriggeredScaleUp
```

## Configuration Options

### Scaling Behavior

```yaml
extraArgs:
  # Scale down configuration
  scale-down-enabled: true
  scale-down-delay-after-add: 10m
  scale-down-unneeded-time: 10m
  scale-down-utilization-threshold: 0.5
  
  # Scale up configuration
  max-node-provision-time: 15m
  
  # Resource limits
  max-nodes-total: 100
  cores-total: "0:1000"
  memory-total: "0:1000Gi"
```

### Expander Strategies

```yaml
extraArgs:
  # Choose expansion strategy
  expander: least-waste  # Options: random, most-pods, least-waste, price, priority
```

### Node Selection

```yaml
extraArgs:
  # Skip nodes with local storage
  skip-nodes-with-local-storage: false
  
  # Skip nodes with system pods
  skip-nodes-with-system-pods: false
  
  # Balance similar node groups
  balance-similar-node-groups: true
```

## Monitoring

### Metrics

The Cluster Autoscaler exposes metrics on `/metrics` endpoint:

- `cluster_autoscaler_nodes_count`
- `cluster_autoscaler_unschedulable_pods_count`
- `cluster_autoscaler_node_groups_count`
- `cluster_autoscaler_max_nodes_count`

### Prometheus Integration

```yaml
# Enable monitoring in values file
podMonitor:
  enabled: true
  namespace: monitoring
  interval: 30s
  path: /metrics
```

## Troubleshooting

### Common Issues

1. **Nodes not scaling up**:
   ```bash
   # Check cluster-autoscaler logs
   kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler
   
   # Check pending pods
   kubectl get pods --all-namespaces --field-selector=status.phase=Pending
   
   # Verify ASG tags
   aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].{Name:AutoScalingGroupName,Tags:Tags}'
   ```

2. **Nodes not scaling down**:
   ```bash
   # Check node utilization
   kubectl top nodes
   
   # Check for pods preventing scale-down
   kubectl describe nodes | grep -A 5 "Non-terminated Pods"
   ```

3. **Permission errors**:
   ```bash
   # Verify IAM role permissions
   aws sts get-caller-identity
   
   # Check service account annotations
   kubectl describe sa cluster-autoscaler -n kube-system
   ```

### Debug Mode

Enable debug logging:

```yaml
extraArgs:
  v: 4  # Increase verbosity (0-10)
  logtostderr: true
  stderrthreshold: info
```

## Best Practices

### 1. Resource Requests

Always set resource requests on your pods:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 2. Pod Disruption Budgets

Use PDBs to control disruption during scale-down:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
```

### 3. Node Affinity

Use node affinity for workload placement:

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: node-type
          operator: In
          values: ["compute"]
```

### 4. Cluster Proportional Autoscaler

For system components, consider using cluster-proportional-autoscaler:

```bash
# Scale DNS based on cluster size
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-proportional-autoscaler/master/examples/dns-horizontal-autoscaler.yaml
```

This setup provides automatic scaling of your EKS cluster based on pod resource requirements and utilization.