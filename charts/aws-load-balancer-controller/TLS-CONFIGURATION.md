# AWS Load Balancer Controller - TLS Configuration

## Overview

The AWS Load Balancer Controller uses a Kubernetes webhook to validate and mutate Ingress and Service resources. This webhook requires TLS certificates for secure communication between the Kubernetes API server and the controller.

## TLS Certificate Management

### Option 1: Self-Signed Certificates (Default)

The controller automatically generates and manages self-signed certificates when `webhookTLS.useCertManager` is set to `false` (default).

**Configuration:**
```yaml
webhookTLS:
  useCertManager: false
  certDuration: 8760h      # 1 year
  certRenewalBefore: 720h  # Renew 30 days before expiration
```

**Pros:**
- ✅ No additional dependencies
- ✅ Automatic certificate generation
- ✅ Automatic certificate rotation
- ✅ Simple setup

**Cons:**
- ⚠️ Self-signed certificates (not trusted by external systems)
- ⚠️ Certificate rotation requires pod restart

### Option 2: cert-manager (Recommended for Production)

Use [cert-manager](https://cert-manager.io/) to manage webhook certificates with automatic rotation.

**Prerequisites:**
1. Install cert-manager in your cluster:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. Verify cert-manager is running:
   ```bash
   kubectl get pods -n cert-manager
   ```

**Configuration:**
```yaml
webhookTLS:
  useCertManager: true
```

**Pros:**
- ✅ Industry-standard certificate management
- ✅ Automatic certificate rotation without pod restart
- ✅ Support for custom CA
- ✅ Better observability

**Cons:**
- ⚠️ Requires cert-manager installation
- ⚠️ Additional complexity

## Webhook Configuration

### Webhook Service

The webhook service exposes the controller's webhook endpoint:

```yaml
webhookService:
  type: ClusterIP      # Internal service only
  port: 9443           # Standard webhook port
  targetPort: 9443     # Container port
```

### Webhook Settings

```yaml
webhook:
  port: 9443                    # Webhook listening port
  timeoutSeconds: 10            # Request timeout
  failurePolicy: Fail           # Fail requests if webhook is unavailable
  namespaceSelector: {}         # Apply to all namespaces
  objectSelector: {}            # Apply to all objects
```

### Failure Policy

**Fail (Recommended for Production):**
- Rejects resources if the webhook is unavailable
- Prevents invalid configurations from being applied
- Ensures consistency and safety

```yaml
webhook:
  failurePolicy: Fail
```

**Ignore (Use with Caution):**
- Allows resources even if webhook is unavailable
- Useful for development or troubleshooting
- May allow invalid configurations

```yaml
webhook:
  failurePolicy: Ignore
```

## Certificate Rotation

### Self-Signed Certificates

Certificates are automatically rotated based on the configuration:

```yaml
webhookTLS:
  certDuration: 8760h       # Certificate valid for 1 year
  certRenewalBefore: 720h   # Renew 30 days before expiration
```

**Rotation Process:**
1. Controller detects certificate approaching expiration
2. Generates new certificate
3. Updates webhook configuration
4. Pod restart may be required

**Monitoring:**
```bash
# Check certificate expiration
kubectl get secret -n aws-load-balancer-controller \
  aws-load-balancer-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates
```

### cert-manager Certificates

Certificates are automatically rotated by cert-manager:

**Monitoring:**
```bash
# Check certificate status
kubectl get certificate -n aws-load-balancer-controller

# Check certificate details
kubectl describe certificate -n aws-load-balancer-controller aws-load-balancer-serving-cert
```

## Troubleshooting

### Webhook Connection Errors

**Symptom:**
```
Error from server (InternalError): Internal error occurred: 
failed calling webhook "..." : Post "https://...": x509: certificate signed by unknown authority
```

**Solutions:**

1. **Check webhook service:**
   ```bash
   kubectl get svc -n aws-load-balancer-controller
   kubectl get endpoints -n aws-load-balancer-controller
   ```

2. **Verify certificate:**
   ```bash
   kubectl get secret -n aws-load-balancer-controller aws-load-balancer-tls
   ```

3. **Check webhook configuration:**
   ```bash
   kubectl get validatingwebhookconfiguration aws-load-balancer-webhook
   kubectl get mutatingwebhookconfiguration aws-load-balancer-webhook
   ```

4. **Restart controller pods:**
   ```bash
   kubectl rollout restart deployment -n aws-load-balancer-controller aws-load-balancer-controller
   ```

### Certificate Expiration

**Check certificate expiration:**
```bash
kubectl get secret -n aws-load-balancer-controller \
  aws-load-balancer-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -enddate
```

**Force certificate renewal:**
```bash
# Delete the secret to trigger regeneration
kubectl delete secret -n aws-load-balancer-controller aws-load-balancer-tls

# Restart the controller
kubectl rollout restart deployment -n aws-load-balancer-controller aws-load-balancer-controller
```

### Webhook Timeout

**Symptom:**
```
Error from server (Timeout): error when creating "ingress.yaml": 
Timeout: request did not complete within requested timeout
```

**Solution:**

Increase webhook timeout:
```yaml
webhook:
  timeoutSeconds: 30  # Increase from default 10s
```

## Security Best Practices

### Production Recommendations

1. **Use cert-manager:**
   ```yaml
   webhookTLS:
     useCertManager: true
   ```

2. **Set failure policy to Fail:**
   ```yaml
   webhook:
     failurePolicy: Fail
   ```

3. **Use appropriate timeouts:**
   ```yaml
   webhook:
     timeoutSeconds: 10  # Balance between reliability and performance
   ```

4. **Monitor certificate expiration:**
   - Set up alerts for certificate expiration
   - Monitor webhook availability

5. **Network policies:**
   - Restrict webhook service access
   - Allow only API server to webhook port

### Development Recommendations

1. **Self-signed certificates are acceptable:**
   ```yaml
   webhookTLS:
     useCertManager: false
   ```

2. **Consider Ignore failure policy for testing:**
   ```yaml
   webhook:
     failurePolicy: Ignore  # Only for development
   ```

## Verification

### Test Webhook Functionality

1. **Create a test Ingress:**
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: test-ingress
     annotations:
       alb.ingress.kubernetes.io/scheme: internet-facing
   spec:
     ingressClassName: alb
     rules:
       - host: test.example.com
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: test-service
                   port:
                     number: 80
   EOF
   ```

2. **Check webhook logs:**
   ```bash
   kubectl logs -n aws-load-balancer-controller \
     -l app.kubernetes.io/name=aws-load-balancer-controller \
     --tail=50
   ```

3. **Verify webhook is called:**
   - Look for webhook validation/mutation logs
   - Check for any TLS errors

### Health Checks

```bash
# Check controller health
kubectl get pods -n aws-load-balancer-controller

# Check webhook endpoints
kubectl get endpoints -n aws-load-balancer-controller

# Check webhook configurations
kubectl get validatingwebhookconfiguration
kubectl get mutatingwebhookconfiguration
```

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Admission Webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [TLS Best Practices](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
