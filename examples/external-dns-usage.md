# External DNS Usage Guide

This guide explains how to configure and use External DNS for automatic DNS management with AWS Route 53 in your EKS cluster.

## Overview

External DNS automatically creates, updates, and deletes DNS records in AWS Route 53 based on Kubernetes resources like Services and Ingresses. It eliminates the need to manually manage DNS records for your applications.

## Prerequisites

### 1. Route 53 Hosted Zone

Ensure you have a Route 53 hosted zone for your domain:

```bash
# Create a hosted zone (if not exists)
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# Get hosted zone ID
aws route53 list-hosted-zones-by-name \
  --dns-name example.com \
  --query 'HostedZones[0].Id' \
  --output text
```

### 2. Update Helm Values

Update your `values-{env}.yaml` files with your domain and hosted zone:

```yaml
# charts/external-dns/values-dev.yaml
domainFilters:
  - "dev.example.com"  # Your dev domain

# charts/external-dns/values-prod.yaml
domainFilters:
  - "example.com"
  - "api.example.com"

zoneIdFilters:
  - "Z1234567890ABC"  # Your Route 53 hosted zone ID
```

## Deployment

### Using GitLab CI/CD

1. **Deploy via Pipeline**:
   ```bash
   # Deploy to dev
   Trigger: deploy:external-dns:dev
   
   # Deploy to prod
   Trigger: deploy:external-dns:prod
   ```

2. **Control via Variables**:
   ```bash
   # Enable installation
   INSTALL_EXTERNAL_DNS=true
   
   # Disable installation
   INSTALL_EXTERNAL_DNS=false
   ```

### Manual Deployment

```bash
# Update dependencies
helm dependency update charts/external-dns

# Deploy to dev
helm upgrade --install external-dns charts/external-dns \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev.yaml

# Deploy to prod
helm upgrade --install external-dns charts/external-dns \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-prod.yaml
```

## Usage Examples

### 1. Service with LoadBalancer

Create a service that automatically gets a DNS record:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/hostname: webapp.dev.example.com
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: webapp
```

### 2. Ingress with Automatic DNS

Create an ingress that automatically manages DNS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    external-dns.alpha.kubernetes.io/hostname: webapp.dev.example.com
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  rules:
    - host: webapp.dev.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webapp-service
                port:
                  number: 80
  tls:
    - hosts:
        - webapp.dev.example.com
      secretName: webapp-tls
```

### 3. Multiple Hostnames

Support multiple hostnames for a single service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/hostname: api.example.com,api-v2.example.com
    external-dns.alpha.kubernetes.io/ttl: "60"
spec:
  type: LoadBalancer
  ports:
    - port: 443
      targetPort: 8443
  selector:
    app: api
```

### 4. Private Zone Support

For private hosted zones:

```yaml
# Update values file
aws:
  zoneType: private  # or "both" for public and private

# Service annotation
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: internal-api.example.local
```

## Advanced Configuration

### 1. Annotation Filters

Restrict External DNS to only process resources with specific annotations:

```yaml
# In values file
annotationFilter: "external-dns.alpha.kubernetes.io/hostname"

# Only services/ingresses with this annotation will be processed
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.example.com
```

### 2. Zone ID Filters

Restrict to specific hosted zones (recommended for production):

```yaml
zoneIdFilters:
  - "Z1234567890ABC"  # Production zone
  - "Z0987654321DEF"  # Staging zone
```

### 3. TXT Record Ownership

External DNS uses TXT records to track ownership:

```yaml
extraArgs:
  - --txt-owner-id=external-dns-prod
  - --txt-prefix=external-dns-
```

### 4. Policy Configuration

Control how External DNS manages records:

```yaml
# Sync policy - manages all records (can delete)
policy: sync

# Upsert-only policy - only creates/updates (safer)
policy: upsert-only
```

## Monitoring and Troubleshooting

### 1. Check External DNS Status

```bash
# Check pod status
kubectl get pods -n external-dns -l app.kubernetes.io/name=external-dns

# Check logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Check events
kubectl get events -n external-dns --sort-by='.lastTimestamp'
```

### 2. Verify DNS Records

```bash
# Check Route 53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query 'ResourceRecordSets[?Type==`A`]'

# Test DNS resolution
nslookup webapp.dev.example.com
dig webapp.dev.example.com
```

### 3. Debug Mode

Enable debug logging:

```yaml
extraArgs:
  - --log-level=debug
  - --events
```

### 4. Dry Run Mode

Test configuration without making changes:

```yaml
dryRun: true
```

## Prometheus Monitoring

### Metrics Available

External DNS exposes metrics on port 7979:

- `external_dns_source_endpoints_total` - Number of endpoints per source
- `external_dns_registry_endpoints_total` - Number of registry endpoints
- `external_dns_controller_last_sync_timestamp_seconds` - Last sync timestamp

### ServiceMonitor Configuration

```yaml
# Enabled in production values
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
```

### Alerting Rules

```yaml
groups:
- name: external-dns
  rules:
  - alert: ExternalDNSDown
    expr: up{job="external-dns"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "External DNS is down"

  - alert: ExternalDNSHighErrorRate
    expr: rate(external_dns_controller_errors_total[5m]) > 0.1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "External DNS high error rate"
```

## Security Best Practices

### 1. Least Privilege IAM

The IAM policy provides minimal required permissions:
- `route53:ChangeResourceRecordSets` - Modify DNS records
- `route53:ListHostedZones` - List available zones
- `route53:GetChange` - Check change status

### 2. Zone Restrictions

Use zone ID filters to restrict access:

```yaml
zoneIdFilters:
  - "Z1234567890ABC"  # Only this zone
```

### 3. Domain Filters

Restrict to specific domains:

```yaml
domainFilters:
  - "example.com"
  - "*.example.com"
```

### 4. Annotation Filters

Require explicit annotation:

```yaml
annotationFilter: "external-dns.alpha.kubernetes.io/hostname"
```

## Common Issues and Solutions

### 1. DNS Records Not Created

```bash
# Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Verify service/ingress annotations
kubectl describe service webapp-service

# Check IAM permissions
aws sts get-caller-identity
```

### 2. Permission Denied Errors

```bash
# Verify IAM role
kubectl describe sa external-dns -n external-dns

# Check Pod Identity association
aws eks list-pod-identity-associations --cluster-name your-cluster
```

### 3. Wrong DNS Records

```bash
# Check TXT records for ownership
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query 'ResourceRecordSets[?Type==`TXT`]'

# Verify txt-owner-id matches
```

### 4. Slow DNS Propagation

```bash
# Check batch settings
extraArgs:
  - --aws-batch-change-size=1000
  - --aws-batch-change-interval=1s

# Monitor Route 53 change status
aws route53 get-change --id /change/C123456789
```

## Integration Examples

### 1. With Cert-Manager

Automatic TLS certificates with DNS validation:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webapp-tls
spec:
  secretName: webapp-tls
  dnsNames:
    - webapp.example.com
  issuer:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

### 2. With Istio

Istio Gateway with automatic DNS:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: webapp-gateway
  annotations:
    external-dns.alpha.kubernetes.io/hostname: webapp.example.com
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - webapp.example.com
      tls:
        mode: SIMPLE
        credentialName: webapp-tls
```

### 3. With AWS Load Balancer Controller

ALB Ingress with automatic DNS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    external-dns.alpha.kubernetes.io/hostname: webapp.example.com
spec:
  rules:
    - host: webapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webapp-service
                port:
                  number: 80
```

External DNS provides seamless DNS automation, reducing operational overhead and ensuring your applications are always accessible via their intended hostnames.