# NGINX Ingress Controller Internal Load Balancer Setup

This guide explains how to configure the NGINX Ingress Controller with an internal AWS Network Load Balancer (NLB) for private access within your VPC.

## Overview

The internal load balancer configuration provides:
- Private access to applications within your VPC
- Enhanced security by not exposing services to the internet
- Integration with private subnets and security groups
- Support for cross-zone load balancing and health checks

## Prerequisites

### 1. VPC and Subnet Information

Gather the following information from your AWS environment:

```bash
# Get VPC ID
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=my-vpc" --query 'Vpcs[0].VpcId' --output text

# Get private subnet IDs
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-abcdef123" "Name=tag:Name,Values=*private*" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Get subnet IDs for different AZs
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-abcdef123" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query 'Subnets[*].SubnetId' \
  --output text
```

### 2. Update Helm Values

Update your values files with the actual VPC and subnet information:

```yaml
# charts/ingress-nginx/values-dev.yaml
loadBalancer:
  scheme: "internal"
  subnets:
    - "subnet-12345678"  # Replace with your actual private subnet ID
    - "subnet-87654321"  # Replace with your actual private subnet ID
  vpc: "vpc-abcdef123"   # Replace with your actual VPC ID

controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-12345678,subnet-87654321"
```

## Configuration Options

### 1. Load Balancer Scheme

```yaml
# Internal load balancer (private access only)
service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"

# Internet-facing load balancer (public access)
service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

### 2. Subnet Selection

```yaml
# Specify exact subnets for load balancer placement
service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-12345678,subnet-87654321"

# Auto-discovery based on tags (alternative)
# Ensure subnets have these tags:
# kubernetes.io/role/internal-elb = 1 (for internal LB)
# kubernetes.io/role/elb = 1 (for internet-facing LB)
```

### 3. Access Control

```yaml
# Restrict access to specific IP ranges
loadBalancerSourceRanges:
  - "10.0.0.0/8"     # Private Class A
  - "172.16.0.0/12"  # Private Class B
  - "192.168.0.0/16" # Private Class C
  - "100.64.0.0/10"  # Carrier-grade NAT
```

### 4. Health Check Configuration

```yaml
service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "http"
service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/healthz"
service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "10254"
service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "6"
service.beta.kubernetes.io/aws-load-balancer-healthy-threshold: "2"
service.beta.kubernetes.io/aws-load-balancer-unhealthy-threshold: "2"
```

## Deployment

### Using GitLab CI/CD

1. **Update Configuration**:
   - Modify `charts/ingress-nginx/values-dev.yaml` and `values-prod.yaml`
   - Replace placeholder subnet and VPC IDs with actual values

2. **Deploy via Pipeline**:
   ```bash
   # Deploy to dev
   Trigger: deploy:ingress-nginx:dev
   
   # Deploy to prod
   Trigger: deploy:ingress-nginx:prod
   ```

### Manual Deployment

```bash
# Update dependencies
helm dependency update charts/ingress-nginx

# Deploy to dev with internal LB
helm upgrade --install ingress-nginx charts/ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f charts/ingress-nginx/values-dev.yaml

# Deploy to prod with internal LB
helm upgrade --install ingress-nginx charts/ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f charts/ingress-nginx/values-prod.yaml
```

## Verification

### 1. Check Load Balancer Status

```bash
# Check service status
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Get load balancer details
kubectl describe svc -n ingress-nginx ingress-nginx-controller

# Check load balancer in AWS
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?Scheme==`internal`]' \
  --output table
```

### 2. Verify Internal Access

```bash
# Get internal load balancer DNS name
LB_DNS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test from within VPC (e.g., from a bastion host or another pod)
curl -H "Host: test.example.com" http://$LB_DNS

# Test health check endpoint
curl http://$LB_DNS:10254/healthz
```

### 3. Check Pod Distribution

```bash
# Verify pods are distributed across AZs
kubectl get pods -n ingress-nginx -o wide

# Check node distribution
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone
```

## Usage Examples

### 1. Internal Application with Ingress

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: internal-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: internal-app
  template:
    metadata:
      labels:
        app: internal-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: internal-app-service
  namespace: default
spec:
  selector:
    app: internal-app
  ports:
    - port: 80
      targetPort: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-app-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: internal-app.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: internal-app-service
            port:
              number: 80
```

### 2. Multiple Host Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: api.internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
  - host: admin.internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 3000
```

### 3. TLS Termination

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - secure.internal.example.com
    secretName: internal-tls-secret
  rules:
  - host: secure.internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 443
```

## Security Considerations

### 1. Network Security Groups

Ensure your security groups allow traffic:

```bash
# Allow HTTP traffic from VPC CIDR
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 80 \
  --cidr 10.0.0.0/16

# Allow HTTPS traffic from VPC CIDR
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.0.0/16
```

### 2. NACLs (Network Access Control Lists)

Verify NACLs allow ingress traffic on required ports.

### 3. DNS Resolution

For internal access, configure Route 53 private hosted zones:

```bash
# Create private hosted zone
aws route53 create-hosted-zone \
  --name internal.example.com \
  --vpc VPCRegion=us-east-1,VPCId=vpc-abcdef123 \
  --caller-reference $(date +%s)
```

## Monitoring and Troubleshooting

### 1. Load Balancer Metrics

Monitor NLB metrics in CloudWatch:
- `ActiveFlowCount_TCP`
- `NewFlowCount_TCP`
- `TargetResponseTime`
- `HealthyHostCount`
- `UnHealthyHostCount`

### 2. NGINX Metrics

Access NGINX metrics:

```bash
# Port-forward to metrics endpoint
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller-metrics 10254:10254

# Access metrics
curl http://localhost:10254/metrics
```

### 3. Common Issues

**Load Balancer Not Created:**
```bash
# Check events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'

# Check controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

**Health Check Failures:**
```bash
# Check health endpoint
kubectl exec -n ingress-nginx deployment/ingress-nginx-controller -- curl localhost:10254/healthz

# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-12345678
```

**DNS Resolution Issues:**
```bash
# Test from within VPC
nslookup internal-app.example.local

# Check Route 53 records
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890
```

## Best Practices

1. **Subnet Selection**: Use private subnets across multiple AZs for high availability
2. **Security Groups**: Apply least privilege access rules
3. **Health Checks**: Configure appropriate health check intervals and thresholds
4. **Monitoring**: Set up CloudWatch alarms for load balancer metrics
5. **DNS**: Use private hosted zones for internal domain resolution
6. **SSL/TLS**: Implement proper certificate management for internal services
7. **Access Logging**: Enable NLB access logs for audit and troubleshooting

This configuration provides a secure, highly available internal load balancer setup for your NGINX Ingress Controller, ensuring private access to your applications within the VPC.