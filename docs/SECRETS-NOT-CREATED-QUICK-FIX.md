# Quick Fix: Kubernetes Secrets Not Created from SecretProviderClass

## TL;DR - The Problem

**Kubernetes secrets defined in `secretObjects` are ONLY created when a pod mounts the CSI volume.**

Your SecretProviderClass exists, but no secrets appear because **no pod is mounting the volume yet**.

## Quick Solution

### Option 1: Deploy Your Application Pod

Your application deployment must include the CSI volume mount:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: edm-gold100
  namespace: gs
spec:
  template:
    spec:
      serviceAccountName: edm-gold100-sa  # Must have IAM role annotation!
      containers:
      - name: app
        image: your-app:latest
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "edm-app-gold100-spc"  # Your SPC name
```

### Option 2: Create a Test Pod

If your app isn't ready, create a test pod to trigger secret creation:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-secrets-mount
  namespace: gs
spec:
  serviceAccountName: edm-gold100-sa
  containers:
  - name: test
    image: busybox:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "edm-app-gold100-spc"
EOF
```

Wait for pod to start:
```bash
kubectl wait --for=condition=Ready pod/test-secrets-mount -n gs --timeout=60s
```

Check if secrets were created:
```bash
kubectl get secrets -n gs | grep edm-gold100
```

## Prerequisites Checklist

Before the pod can mount secrets, verify:

### 1. AWS Provider is Installed

```bash
kubectl get daemonset -n secrets-store-csi-driver secrets-store-csi-driver-provider-aws
```

**If not found**, deploy it:
```bash
# Via GitLab CI/CD
# Run job: deploy:secrets-store-provider-aws:dev

# Or via Helm
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml
```

### 2. Service Account Has IAM Role

```bash
kubectl get sa edm-gold100-sa -n gs -o yaml | grep eks.amazonaws.com/role-arn
```

**If not found**, add annotation:
```bash
kubectl annotate sa edm-gold100-sa -n gs \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev
```

### 3. Secrets Exist in AWS

```bash
aws secretsmanager list-secrets --region us-east-1 | grep edm-gold100
```

## Common Errors and Fixes

### Error: "provider not found: provider 'aws'"

**Fix**: Install AWS Secrets Manager Provider (see step 1 above)

### Error: "AccessDeniedException"

**Fix**: Verify IAM role has permissions:
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:*"
}
```

### Error: "SecretNotFound"

**Fix**: Verify secret exists in AWS Secrets Manager in the correct region

### Pod Stuck in "ContainerCreating"

**Check pod events**:
```bash
kubectl describe pod <pod-name> -n gs
```

Look for mount errors in the events section.

## Verification Steps

After deploying a pod with the CSI volume:

```bash
# 1. Check pod is running
kubectl get pods -n gs

# 2. Check pod mounted the volume
kubectl describe pod <pod-name> -n gs | grep -A 5 "Mounts:"

# 3. Check secrets were created
kubectl get secrets -n gs | grep edm-gold100

# Expected output:
# edm-gold100-db-owner-secret
# edm-gold100-app-user-secret
# edm-gold100-sa-secret
# edm-gold100-keycloak-secret
# edm-gold100-certificate-passphrase-secret
# ... (all secrets from secretObjects)

# 4. Verify secret content
kubectl get secret edm-gold100-db-owner-secret -n gs -o yaml

# 5. Check mounted files in pod
kubectl exec <pod-name> -n gs -- ls -la /mnt/secrets/
```

## Example Files

See these files for complete examples:
- `examples/edm-gold100-deployment-example.yaml` - Full deployment example
- `docs/SECRETPROVIDERCLASS-TROUBLESHOOTING.md` - Detailed troubleshooting

## Summary

1. ✅ SecretProviderClass created
2. ❓ **Pod with CSI volume mount** ← You need this!
3. ✅ Secrets automatically created when pod starts

**The key**: Secrets won't appear until a pod successfully mounts the CSI volume!
