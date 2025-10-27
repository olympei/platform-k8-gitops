# SSL Certificate Setup for NGINX Ingress Controller

This guide explains how to configure SSL/TLS certificates for the NGINX Ingress Controller using AWS Certificate Manager (ACM) and Network Load Balancer (NLB) SSL termination.

## Overview

The SSL configuration provides:
- SSL termination at the AWS Network Load Balancer level
- Integration with AWS Certificate Manager (ACM)
- Support for multiple certificates and domains
- Automatic certificate renewal through ACM
- Enhanced security with configurable SSL policies

## Prerequisites

### 1. AWS Certificate Manager (ACM) Certificate

You need to create or import SSL certificates in ACM before configuring the ingress controller.

#### Option A: Request a Certificate from ACM

```bash
# Request a certificate for your domain
aws acm request-certificate \
  --domain-name "*.internal.example.com" \
  --subject-alternative-names "internal.example.com" \
  --validation-method DNS \
  --region us-east-1

# Get certificate ARN
aws acm list-certificates \
  --query 'CertificateSummaryList[?DomainName==`*.internal.example.com`].CertificateArn' \
  --output text
```

#### Option B: Import an Existing Certificate

```bash
# Import your own certificate
aws acm import-certificate \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --certificate-chain fileb://certificate-chain.pem \
  --region us-east-1
```

### 2. DNS Validation (for ACM-issued certificates)

If using ACM to issue certificates, you need to validate domain ownership:

```bash
# Get validation records
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012" \
  --query 'Certificate.DomainValidationOptions'

# Add CNAME records to your DNS (Route 53 example)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://dns-validation.json
```

## Configuration

### 1. Update Helm Values

Update your values files with the ACM certificate ARN:

#### Development Environment
```yaml
# charts/ingress-nginx/values-dev.yaml
ssl:
  enabled: true
  certificateArn: "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/dev-12345678-1234-1234-1234-123456789012"
  sslPolicy: "ELBSecurityPolicy-TLS-1-2-2017-01"

controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/dev-12345678-1234-1234-1234-123456789012"
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "https"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
```

#### Production Environment
```yaml
# charts/ingress-nginx/values-prod.yaml
ssl:
  enabled: true
  certificateArn: "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012"
  sslPolicy: "ELBSecurityPolicy-TLS-1-2-2017-01"
  additionalCertificates:
    - "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/87654321-4321-4321-4321-210987654321"
```

### 2. SSL Policies

Choose appropriate SSL policies based on your security requirements:

```yaml
# Modern security (recommended for new applications)
sslPolicy: "ELBSecurityPolicy-TLS-1-2-2017-01"

# High security (for sensitive applications)
sslPolicy: "ELBSecurityPolicy-FS-1-2-Res-2020-10"

# Backward compatibility (if you need to support older clients)
sslPolicy: "ELBSecurityPolicy-2016-08"
```

### 3. Multiple Certificates

For multiple domains or wildcard + specific domain certificates:

```yaml
ssl:
  certificateArn: "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/primary-cert"
  additionalCertificates:
    - "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/secondary-cert"
    - "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/api-cert"
```

## Deployment

### Using GitLab CI/CD

1. **Update Certificate ARNs**: Replace placeholder ARNs in values files
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

# Deploy with SSL configuration
helm upgrade --install ingress-nginx charts/ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f charts/ingress-nginx/values-prod.yaml
```

## Verification

### 1. Check Load Balancer Configuration

```bash
# Get load balancer ARN
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `ingress-nginx`)].LoadBalancerArn' \
  --output text)

# Check listeners
aws elbv2 describe-listeners --load-balancer-arn $LB_ARN

# Verify SSL certificate
aws elbv2 describe-listener-certificates --listener-arn $LISTENER_ARN
```

### 2. Test SSL Connection

```bash
# Get load balancer DNS name
LB_DNS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test HTTPS connection
curl -k https://$LB_DNS

# Test with specific hostname
curl -k -H "Host: app.internal.example.com" https://$LB_DNS

# Check certificate details
openssl s_client -connect $LB_DNS:443 -servername app.internal.example.com
```

### 3. Verify Certificate Chain

```bash
# Check certificate chain
echo | openssl s_client -connect $LB_DNS:443 -servername app.internal.example.com 2>/dev/null | \
  openssl x509 -noout -text
```

## Usage Examples

### 1. Basic HTTPS Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-app
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app.internal.example.com
    # No secretName needed - SSL terminated at LB
  rules:
  - host: app.internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### 2. Force HTTPS Redirect

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: force-https
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
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
              number: 80
```

### 3. Multiple Domains with Different Certificates

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-domain
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

## Security Best Practices

### 1. Certificate Management

```bash
# Monitor certificate expiration
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012" \
  --query 'Certificate.NotAfter'

# Set up CloudWatch alarms for certificate expiration
aws cloudwatch put-metric-alarm \
  --alarm-name "ACM-Certificate-Expiration" \
  --alarm-description "Certificate expiring soon" \
  --metric-name DaysToExpiry \
  --namespace AWS/CertificateManager \
  --statistic Minimum \
  --period 86400 \
  --threshold 30 \
  --comparison-operator LessThanThreshold
```

### 2. Security Headers

Configure security headers in NGINX:

```yaml
controller:
  config:
    # Security headers
    add-headers: "ingress-nginx/security-headers"
    # HSTS
    hsts: "true"
    hsts-max-age: "31536000"
    hsts-include-subdomains: "true"
    # Other security settings
    ssl-protocols: "TLSv1.2 TLSv1.3"
    ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384"
```

Create security headers ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-headers
  namespace: ingress-nginx
data:
  X-Frame-Options: "DENY"
  X-Content-Type-Options: "nosniff"
  X-XSS-Protection: "1; mode=block"
  Referrer-Policy: "strict-origin-when-cross-origin"
  Content-Security-Policy: "default-src 'self'"
```

### 3. Access Control

```yaml
# Restrict access by IP
nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12"

# Client certificate authentication
nginx.ingress.kubernetes.io/auth-tls-verify-client: "on"
nginx.ingress.kubernetes.io/auth-tls-secret: "default/ca-secret"
```

## Troubleshooting

### Common Issues

1. **Certificate Not Found**:
   ```bash
   # Verify certificate exists in correct region
   aws acm list-certificates --region us-east-1
   
   # Check certificate status
   aws acm describe-certificate --certificate-arn "arn:aws:acm:..."
   ```

2. **SSL Handshake Failures**:
   ```bash
   # Check SSL policy compatibility
   nmap --script ssl-enum-ciphers -p 443 $LB_DNS
   
   # Test with specific TLS version
   openssl s_client -tls1_2 -connect $LB_DNS:443
   ```

3. **Mixed Content Issues**:
   ```yaml
   # Ensure proper forwarded headers
   controller:
     config:
       use-forwarded-headers: "true"
       compute-full-forwarded-for: "true"
   ```

### Monitoring

Set up monitoring for SSL certificates:

```yaml
# Prometheus rule for certificate expiration
groups:
- name: ssl-certificates
  rules:
  - alert: SSLCertificateExpiringSoon
    expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "SSL certificate expiring soon"
      description: "SSL certificate for {{ $labels.instance }} expires in less than 30 days"
```

## Advanced Configuration

### 1. Custom SSL Policies

Create custom SSL policies for specific security requirements:

```bash
# Create custom policy (AWS CLI v2)
aws elbv2 create-ssl-policy \
  --name "Custom-TLS-Policy-2023" \
  --ssl-protocols TLSv1.2 TLSv1.3 \
  --ciphers ECDHE-RSA-AES128-GCM-SHA256 ECDHE-RSA-AES256-GCM-SHA384
```

### 2. Certificate Rotation

Automate certificate rotation:

```bash
#!/bin/bash
# Certificate rotation script
NEW_CERT_ARN="arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/new-cert-id"
LB_ARN=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[0].LoadBalancerArn' --output text)
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $LB_ARN --query 'Listeners[?Port==`443`].ListenerArn' --output text)

# Update listener certificate
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --certificates CertificateArn=$NEW_CERT_ARN
```

### 3. Multi-Region Setup

For multi-region deployments, ensure certificates are available in each region:

```bash
# Copy certificate to another region (not directly supported, need to re-import)
aws acm import-certificate \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --certificate-chain fileb://certificate-chain.pem \
  --region eu-west-1
```

This SSL configuration provides secure, scalable HTTPS termination for your NGINX Ingress Controller, leveraging AWS's managed certificate services for automatic renewal and high availability.