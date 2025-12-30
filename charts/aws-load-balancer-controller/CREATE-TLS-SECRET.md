# Creating TLS Secret for AWS Load Balancer Controller

## Overview

The AWS Load Balancer Controller webhook requires TLS certificates. You can provide your own certificates via a Kubernetes secret named `aws-load-balancer-webhook-tls`.

## Prerequisites

- OpenSSL installed
- kubectl configured with cluster access
- Namespace `aws-load-balancer-controller` created

## Option 1: Create Self-Signed Certificate

### Step 1: Generate Private Key and Certificate

```bash
# Set variables
NAMESPACE="aws-load-balancer-controller"
SECRET_NAME="aws-load-balancer-webhook-tls"
SERVICE_NAME="aws-load-balancer-webhook-service"
CERT_DIR="./webhook-certs"

# Create directory for certificates
mkdir -p "$CERT_DIR"

# Generate private key
openssl genrsa -out "$CERT_DIR/tls.key" 2048

# Generate certificate signing request (CSR)
cat > "$CERT_DIR/csr.conf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = ${SERVICE_NAME}.${NAMESPACE}.svc

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SERVICE_NAME}
DNS.2 = ${SERVICE_NAME}.${NAMESPACE}
DNS.3 = ${SERVICE_NAME}.${NAMESPACE}.svc
DNS.4 = ${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local
EOF

# Generate CSR
openssl req -new -key "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.csr" \
  -config "$CERT_DIR/csr.conf"

# Generate self-signed certificate (valid for 1 year)
openssl x509 -req -in "$CERT_DIR/tls.csr" \
  -signkey "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.crt" \
  -days 365 \
  -extensions v3_req \
  -extfile "$CERT_DIR/csr.conf"

# Verify certificate
openssl x509 -in "$CERT_DIR/tls.crt" -text -noout
```

### Step 2: Create Kubernetes Secret

```bash
# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create secret
kubectl create secret tls "$SECRET_NAME" \
  --cert="$CERT_DIR/tls.crt" \
  --key="$CERT_DIR/tls.key" \
  -n "$NAMESPACE"

# Verify secret
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE"
kubectl describe secret "$SECRET_NAME" -n "$NAMESPACE"
```

### Step 3: Get CA Bundle for Webhook Configuration

```bash
# Extract CA bundle (base64 encoded)
CA_BUNDLE=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.data.tls\.crt}')

echo "CA Bundle (base64):"
echo "$CA_BUNDLE"

# Decode to verify
echo "$CA_BUNDLE" | base64 -d | openssl x509 -text -noout
```

## Option 2: Use Existing Certificate

If you already have a certificate from a CA:

```bash
NAMESPACE="aws-load-balancer-controller"
SECRET_NAME="aws-load-balancer-webhook-tls"

# Create secret from existing files
kubectl create secret tls "$SECRET_NAME" \
  --cert=/path/to/your/tls.crt \
  --key=/path/to/your/tls.key \
  -n "$NAMESPACE"
```

## Option 3: Use cert-manager (Recommended)

### Step 1: Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Step 2: Create Certificate Resource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: aws-load-balancer-webhook-cert
  namespace: aws-load-balancer-controller
spec:
  secretName: aws-load-balancer-webhook-tls
  duration: 8760h  # 1 year
  renewBefore: 720h  # 30 days
  subject:
    organizations:
      - aws-load-balancer-controller
  commonName: aws-load-balancer-webhook-service.aws-load-balancer-controller.svc
  dnsNames:
    - aws-load-balancer-webhook-service
    - aws-load-balancer-webhook-service.aws-load-balancer-controller
    - aws-load-balancer-webhook-service.aws-load-balancer-controller.svc
    - aws-load-balancer-webhook-service.aws-load-balancer-controller.svc.cluster.local
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

### Step 3: Verify Certificate

```bash
# Check certificate status
kubectl get certificate -n aws-load-balancer-controller

# Check secret
kubectl get secret aws-load-balancer-webhook-tls -n aws-load-balancer-controller
```

## Secret Format

The secret must contain two keys:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-load-balancer-webhook-tls
  namespace: aws-load-balancer-controller
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>
```

## Certificate Requirements

### Subject Alternative Names (SANs)

The certificate must include these SANs:
- `aws-load-balancer-webhook-service`
- `aws-load-balancer-webhook-service.aws-load-balancer-controller`
- `aws-load-balancer-webhook-service.aws-load-balancer-controller.svc`
- `aws-load-balancer-webhook-service.aws-load-balancer-controller.svc.cluster.local`

### Key Usage

- Digital Signature
- Key Encipherment
- Server Authentication

### Validity Period

- Recommended: 1 year
- Minimum: 90 days
- Maximum: 2 years

## Verification

### Check Secret Exists

```bash
kubectl get secret aws-load-balancer-webhook-tls \
  -n aws-load-balancer-controller
```

### Verify Certificate Content

```bash
# Extract and decode certificate
kubectl get secret aws-load-balancer-webhook-tls \
  -n aws-load-balancer-controller \
  -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -text -noout
```

### Check Certificate Expiration

```bash
kubectl get secret aws-load-balancer-webhook-tls \
  -n aws-load-balancer-controller \
  -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -dates
```

### Verify SANs

```bash
kubectl get secret aws-load-balancer-webhook-tls \
  -n aws-load-balancer-controller \
  -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -text | \
  grep -A1 "Subject Alternative Name"
```

## Certificate Rotation

### Manual Rotation

1. **Generate new certificate:**
   ```bash
   # Follow steps in Option 1 to generate new certificate
   ```

2. **Update secret:**
   ```bash
   kubectl create secret tls aws-load-balancer-webhook-tls \
     --cert="$CERT_DIR/tls.crt" \
     --key="$CERT_DIR/tls.key" \
     -n aws-load-balancer-controller \
     --dry-run=client -o yaml | \
     kubectl apply -f -
   ```

3. **Restart controller:**
   ```bash
   kubectl rollout restart deployment \
     -n aws-load-balancer-controller \
     aws-load-balancer-controller
   ```

### Automatic Rotation with cert-manager

cert-manager automatically rotates certificates based on the `renewBefore` setting:

```yaml
spec:
  renewBefore: 720h  # Renew 30 days before expiration
```

**Monitor rotation:**
```bash
# Watch certificate events
kubectl get events -n aws-load-balancer-controller \
  --field-selector involvedObject.name=aws-load-balancer-webhook-cert

# Check certificate status
kubectl describe certificate aws-load-balancer-webhook-cert \
  -n aws-load-balancer-controller
```

## Troubleshooting

### Secret Not Found

**Error:**
```
Error: secret "aws-load-balancer-webhook-tls" not found
```

**Solution:**
```bash
# Check if secret exists
kubectl get secret -n aws-load-balancer-controller

# Create secret if missing
# Follow steps in Option 1, 2, or 3 above
```

### Invalid Certificate

**Error:**
```
x509: certificate signed by unknown authority
```

**Solution:**
1. Verify certificate SANs match service name
2. Check certificate is not expired
3. Ensure certificate is properly formatted

### Certificate Expired

**Check expiration:**
```bash
kubectl get secret aws-load-balancer-webhook-tls \
  -n aws-load-balancer-controller \
  -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -enddate
```

**Rotate certificate:**
```bash
# Delete old secret
kubectl delete secret aws-load-balancer-webhook-tls \
  -n aws-load-balancer-controller

# Create new secret (follow Option 1, 2, or 3)

# Restart controller
kubectl rollout restart deployment \
  -n aws-load-balancer-controller \
  aws-load-balancer-controller
```

## Security Best Practices

1. **Use Strong Keys:**
   - Minimum 2048-bit RSA keys
   - Prefer 4096-bit for production

2. **Limit Certificate Validity:**
   - Maximum 1 year for production
   - Rotate regularly

3. **Protect Private Keys:**
   - Never commit to version control
   - Use RBAC to restrict secret access
   - Consider using sealed-secrets or external-secrets

4. **Monitor Expiration:**
   - Set up alerts for certificate expiration
   - Automate rotation with cert-manager

5. **Use cert-manager in Production:**
   - Automatic rotation
   - Better observability
   - Industry standard

## Integration with Values Files

The secret name is configured in the values files:

```yaml
# values-dev-direct.yaml / values-prod-direct.yaml
webhookTLS:
  existingSecret: "aws-load-balancer-webhook-tls"
```

To use a different secret name:

```yaml
webhookTLS:
  existingSecret: "my-custom-webhook-tls"
```

## Complete Example Script

```bash
#!/bin/bash
set -e

# Configuration
NAMESPACE="aws-load-balancer-controller"
SECRET_NAME="aws-load-balancer-webhook-tls"
SERVICE_NAME="aws-load-balancer-webhook-service"
CERT_DIR="./webhook-certs"

echo "Creating TLS secret for AWS Load Balancer Controller..."

# Create directory
mkdir -p "$CERT_DIR"

# Generate private key
echo "Generating private key..."
openssl genrsa -out "$CERT_DIR/tls.key" 2048

# Create CSR config
cat > "$CERT_DIR/csr.conf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = ${SERVICE_NAME}.${NAMESPACE}.svc

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SERVICE_NAME}
DNS.2 = ${SERVICE_NAME}.${NAMESPACE}
DNS.3 = ${SERVICE_NAME}.${NAMESPACE}.svc
DNS.4 = ${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local
EOF

# Generate CSR
echo "Generating CSR..."
openssl req -new -key "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.csr" \
  -config "$CERT_DIR/csr.conf"

# Generate certificate
echo "Generating certificate..."
openssl x509 -req -in "$CERT_DIR/tls.csr" \
  -signkey "$CERT_DIR/tls.key" \
  -out "$CERT_DIR/tls.crt" \
  -days 365 \
  -extensions v3_req \
  -extfile "$CERT_DIR/csr.conf"

# Create namespace
echo "Creating namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create secret
echo "Creating secret..."
kubectl create secret tls "$SECRET_NAME" \
  --cert="$CERT_DIR/tls.crt" \
  --key="$CERT_DIR/tls.key" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ TLS secret created successfully!"
echo ""
echo "Verify with:"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo "  kubectl describe secret $SECRET_NAME -n $NAMESPACE"
```

Save this as `create-webhook-tls.sh` and run:
```bash
chmod +x create-webhook-tls.sh
./create-webhook-tls.sh
```
