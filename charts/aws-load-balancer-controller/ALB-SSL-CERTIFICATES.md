# ALB SSL/TLS Certificate Configuration

## Overview

The AWS Load Balancer Controller can automatically configure SSL/TLS certificates for Application Load Balancers (ALBs) created from Kubernetes Ingress resources. This guide covers how to configure default certificates and per-Ingress certificate overrides.

## Prerequisites

- SSL/TLS certificates uploaded to AWS Certificate Manager (ACM)
- AWS Load Balancer Controller deployed
- Proper IAM permissions for the controller to access ACM

## Default SSL Certificate Configuration

### Configure in Values Files

Set a default certificate that will be used for all HTTPS Ingresses unless overridden:

**Development (`values-dev-direct.yaml`):**
```yaml
defaultSSLCertificate:
  arn: "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234-5678-90ab-cdef-1234567890ab"

sslPolicy: "ELBSecurityPolicy-TLS-1-2-2017-01"
```

**Production (`values-prod-direct.yaml`):**
```yaml
defaultSSLCertificate:
  arn: "arn:aws:acm:us-east-1:123456789012:certificate/prod5678-90ab-cdef-1234-567890abcdef"

sslPolicy: "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"  # More secure for production
```

## Creating Certificates in ACM

### Option 1: Request a Public Certificate

```bash
# Request certificate for your domain
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --region us-east-1

# Get certificate ARN
aws acm list-certificates --region us-east-1
```

### Option 2: Import an Existing Certificate

```bash
# Import certificate
aws acm import-certificate \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --certificate-chain fileb://certificate-chain.pem \
  --region us-east-1
```

### Validate Certificate

For DNS validation:

```bash
# Get validation records
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/abcd1234... \
  --region us-east-1

# Add the CNAME records to your DNS
# Wait for validation (can take up to 30 minutes)
```

## SSL Policies

### Available Policies

| Policy | TLS Versions | Use Case |
|--------|-------------|----------|
| `ELBSecurityPolicy-2016-08` | TLS 1.0, 1.1, 1.2 | Legacy compatibility |
| `ELBSecurityPolicy-TLS-1-2-2017-01` | TLS 1.2 | Balanced security |
| `ELBSecurityPolicy-TLS-1-2-Ext-2018-06` | TLS 1.2 | Enhanced security |
| `ELBSecurityPolicy-FS-1-2-Res-2019-08` | TLS 1.2 | Forward secrecy |
| `ELBSecurityPolicy-TLS-1-3-2021-06` | TLS 1.2, 1.3 | **Recommended** |

### Recommended Policies

**Development:**
```yaml
sslPolicy: "ELBSecurityPolicy-TLS-1-2-2017-01"
```

**Production:**
```yaml
sslPolicy: "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
# Or for maximum security:
sslPolicy: "ELBSecurityPolicy-TLS-1-3-2021-06"
```

## Ingress Configuration

### Basic HTTPS Ingress with Default Certificate

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # HTTPS listener will use the default certificate
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    # Redirect HTTP to HTTPS
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

### Override Default Certificate Per-Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    # Override with specific certificate
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/specific-cert-id"
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

### Multiple Certificates (SNI)

Use Server Name Indication (SNI) to serve multiple certificates on the same ALB:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-domain-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    # Multiple certificates separated by commas
    alb.ingress.kubernetes.io/certificate-arn: |
      arn:aws:acm:us-east-1:123456789012:certificate/cert1-id,
      arn:aws:acm:us-east-1:123456789012:certificate/cert2-id
spec:
  ingressClassName: alb
  rules:
    - host: app1.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app1-service
                port:
                  number: 80
    - host: app2.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app2-service
                port:
                  number: 80
```

### Custom SSL Policy Per-Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    # Override SSL policy
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-3-2021-06"
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

## Advanced Configurations

### HTTP to HTTPS Redirect

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
```

### HTTPS Only (No HTTP)

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
```

### Custom Redirect Rules

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/actions.ssl-redirect: |
      {
        "Type": "redirect",
        "RedirectConfig": {
          "Protocol": "HTTPS",
          "Port": "443",
          "StatusCode": "HTTP_301"
        }
      }
```

### Mutual TLS (mTLS)

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/cert-id"
    # Enable mutual TLS
    alb.ingress.kubernetes.io/mutual-authentication: |
      {
        "mode": "verify",
        "trustStoreArn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:truststore/my-trust-store/1234567890abcdef",
        "ignoreClientCertificateExpiry": false
      }
```

## Certificate Discovery

The controller can automatically discover certificates:

### By Domain Name

```yaml
metadata:
  annotations:
    # Controller will find certificate matching this domain
    alb.ingress.kubernetes.io/certificate-arn: "auto-discover"
spec:
  rules:
    - host: app.example.com  # Certificate must match this domain
```

### By Tags

Tag your ACM certificates:

```bash
aws acm add-tags-to-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/cert-id \
  --tags Key=kubernetes.io/ingress-name,Value=my-app \
         Key=kubernetes.io/namespace,Value=default
```

## Verification

### Check ALB Configuration

```bash
# Get ALB ARN from Ingress
ALB_ARN=$(kubectl get ingress my-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | \
  xargs -I {} aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='{}'].LoadBalancerArn" --output text)

# Check listeners
aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN"

# Check SSL certificates
aws elbv2 describe-listener-certificates \
  --listener-arn <listener-arn-from-above>
```

### Test SSL Configuration

```bash
# Test SSL connection
openssl s_client -connect app.example.com:443 -servername app.example.com

# Check certificate details
echo | openssl s_client -connect app.example.com:443 -servername app.example.com 2>/dev/null | \
  openssl x509 -noout -text

# Test SSL Labs
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=app.example.com
```

### Verify Certificate in ACM

```bash
# List certificates
aws acm list-certificates --region us-east-1

# Get certificate details
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/cert-id \
  --region us-east-1
```

## Troubleshooting

### Certificate Not Found

**Error:**
```
Failed to reconcile: certificate not found
```

**Solutions:**
1. Verify certificate ARN is correct
2. Check certificate is in the same region as ALB
3. Ensure IAM permissions allow ACM access
4. Verify certificate status is "Issued"

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/cert-id \
  --region us-east-1 \
  --query 'Certificate.Status'
```

### Certificate Validation Pending

**Check validation status:**
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/cert-id \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions'
```

**Add DNS validation records:**
```bash
# Get CNAME records from output above
# Add to your DNS provider
```

### Wrong Certificate Applied

**Check Ingress annotations:**
```bash
kubectl get ingress my-app -o yaml | grep certificate-arn
```

**Check ALB listener:**
```bash
aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[?Protocol==`HTTPS`].Certificates'
```

### SSL Policy Not Applied

**Verify annotation:**
```yaml
alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
```

**Check ALB listener:**
```bash
aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[?Protocol==`HTTPS`].SslPolicy'
```

## Best Practices

### Certificate Management

1. **Use ACM for Certificate Management:**
   - Automatic renewal
   - Free for AWS services
   - Integrated with ALB

2. **Wildcard Certificates:**
   ```bash
   aws acm request-certificate \
     --domain-name "*.example.com" \
     --subject-alternative-names "example.com" \
     --validation-method DNS
   ```

3. **Certificate Rotation:**
   - ACM automatically renews certificates
   - No action needed for ACM-managed certificates
   - For imported certificates, set up renewal reminders

4. **Multiple Certificates:**
   - Use SNI for multiple domains
   - One certificate per domain or wildcard

### Security

1. **Use Strong SSL Policies:**
   ```yaml
   # Production
   sslPolicy: "ELBSecurityPolicy-TLS-1-3-2021-06"
   ```

2. **Enable HTTPS Redirect:**
   ```yaml
   alb.ingress.kubernetes.io/ssl-redirect: '443'
   ```

3. **Disable Weak Protocols:**
   - Avoid `ELBSecurityPolicy-2016-08` (supports TLS 1.0)
   - Use TLS 1.2 minimum

4. **Monitor Certificate Expiration:**
   ```bash
   # Set up CloudWatch alarm for certificate expiration
   aws cloudwatch put-metric-alarm \
     --alarm-name acm-cert-expiration \
     --alarm-description "Alert when certificate expires soon" \
     --metric-name DaysToExpiry \
     --namespace AWS/CertificateManager \
     --statistic Minimum \
     --period 86400 \
     --evaluation-periods 1 \
     --threshold 30 \
     --comparison-operator LessThanThreshold
   ```

### Cost Optimization

1. **Reuse Certificates:**
   - Use wildcard certificates for multiple subdomains
   - Share certificates across Ingresses

2. **Certificate Consolidation:**
   - Use SANs (Subject Alternative Names) for multiple domains
   - Reduce number of certificates to manage

## Complete Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-app
  namespace: production
  annotations:
    # ALB Configuration
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: production-alb
    
    # SSL/TLS Configuration
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/prod-cert-id"
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-3-2021-06"
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    
    # Health Check
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
    
    # Tags
    alb.ingress.kubernetes.io/tags: Environment=production,Team=platform
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: production-app-service
                port:
                  number: 8080
```

## References

- [AWS Load Balancer Controller Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [ACM User Guide](https://docs.aws.amazon.com/acm/latest/userguide/)
- [ELB SSL Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies)
- [SSL Labs Testing](https://www.ssllabs.com/ssltest/)
