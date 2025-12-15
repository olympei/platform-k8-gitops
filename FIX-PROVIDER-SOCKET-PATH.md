# Fix: Provider Socket Path Mismatch

## Problem
The CSI driver was configured with the wrong provider socket directory:
- **Configured**: `/etc/kubernetes/secrets-store-csi-providers`
- **Required**: `/var/run/secrets-store-csi-providers`

This caused the error:
```
ls: cannot access /var/run/secrets-store-csi-providers/: No such file or directory
```

## Root Cause
The `providersDir` setting in the CSI driver values files was pointing to the wrong location.

## Fix Applied

Updated both values files:
- `charts/secrets-store-csi-driver/values-dev.yaml`
- `charts/secrets-store-csi-driver/values-prod.yaml`

Changed:
```yaml
providersDir: /etc/kubernetes/secrets-store-csi-providers  # ❌ WRONG
```

To:
```yaml
providersDir: /var/run/secrets-store-csi-providers  # ✅ CORRECT
```

## Apply the Fix

### Option 1: Upgrade via Helm (Recommended)

```bash
# Dev environment
helm upgrade secrets-store-csi-driver \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system \
  -f charts/secrets-store-csi-driver/values-dev.yaml

# Prod environment
helm upgrade secrets-store-csi-driver \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system \
  -f charts/secrets-store-csi-driver/values-prod.yaml
```

### Option 2: Via GitLab CI/CD

Trigger the deployment job:
```bash
# For dev
deploy:secrets-store-csi-driver:dev

# For prod
deploy:secrets-store-csi-driver:prod
```

### Option 3: Quick Patch (Temporary)

If you need an immediate fix without redeploying:

```bash
# Edit the DaemonSet directly
kubectl edit daemonset secrets-store-csi-driver -n kube-system

# Find the volume mount section and change:
# /etc/kubernetes/secrets-store-csi-providers
# to:
# /var/run/secrets-store-csi-providers

# Save and exit - pods will restart automatically
```

## Verification After Fix

### Step 1: Wait for Rollout

```bash
# Check rollout status
kubectl rollout status daemonset/secrets-store-csi-driver -n kube-system

# Should show: daemon set "secrets-store-csi-driver" successfully rolled out
```

### Step 2: Verify Directory Exists

```bash
# Get CSI driver pod name
CSI_POD=$(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}')

# Check directory now exists
kubectl exec -n kube-system $CSI_POD -- ls -la /var/run/secrets-store-csi-providers/
```

**Expected output:**
```
total 0
drwxr-xr-x    2 root     root            60 Dec 12 10:00 .
drwxr-xr-x    3 root     root            80 Dec 12 10:00 ..
srwxr-xr-x    1 root     root             0 Dec 12 10:00 aws.sock
```

### Step 3: Verify AWS Provider Socket

```bash
# Check for aws.sock file
kubectl exec -n kube-system $CSI_POD -- ls -la /var/run/secrets-store-csi-providers/ | findstr aws.sock

# Should show: srwxr-xr-x    1 root     root    0 Dec 12 10:00 aws.sock
```

### Step 4: Test Communication

```bash
# Create test SecretProviderClass
kubectl apply -f - <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-provider-communication
  namespace: default
spec:
  provider: aws
  parameters:
    region: us-east-1
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
EOF

# Check for errors
kubectl describe secretproviderclass test-provider-communication -n default

# Should NOT show "provider not found" error

# Cleanup
kubectl delete secretproviderclass test-provider-communication -n default
```

## Why This Path?

The path `/var/run/secrets-store-csi-providers/` is the standard location because:

1. **Temporary Runtime Data**: `/var/run` is for runtime data that doesn't persist across reboots
2. **Socket Files**: Unix domain sockets are typically placed in `/var/run`
3. **Standard Convention**: This is the default path used by the Secrets Store CSI Driver
4. **AWS Provider Default**: The AWS provider creates its socket at `/var/run/secrets-store-csi-providers/aws.sock`

## Troubleshooting

### If Directory Still Missing After Fix

```bash
# Check DaemonSet volume configuration
kubectl get daemonset secrets-store-csi-driver -n kube-system -o yaml | findstr -A 10 "providervol"

# Should show:
# - name: providervol
#   hostPath:
#     path: /var/run/secrets-store-csi-providers
#     type: DirectoryOrCreate
```

### If AWS Provider Socket Missing

```bash
# Check AWS provider is running
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# Check AWS provider logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50

# Restart AWS provider if needed
kubectl rollout restart daemonset/csi-secrets-store-provider-aws -n kube-system
```

### If Still Having Issues

```bash
# Restart both DaemonSets
kubectl rollout restart daemonset/secrets-store-csi-driver -n kube-system
kubectl rollout restart daemonset/csi-secrets-store-provider-aws -n kube-system

# Wait for both to be ready
kubectl rollout status daemonset/secrets-store-csi-driver -n kube-system
kubectl rollout status daemonset/csi-secrets-store-provider-aws -n kube-system

# Verify again
kubectl exec -n kube-system $(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/run/secrets-store-csi-providers/
```

## Summary

✅ **Fixed**: Changed `providersDir` from `/etc/kubernetes/secrets-store-csi-providers` to `/var/run/secrets-store-csi-providers`

✅ **Action Required**: Upgrade the CSI driver Helm release with the corrected values file

✅ **Verification**: After upgrade, the directory should exist and contain `aws.sock`

This fix ensures the CSI driver and AWS provider can communicate via the Unix domain socket.

