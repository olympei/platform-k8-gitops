# Troubleshooting: Missing Socket Directory

## Error
```
ls: cannot access /var/run/secrets-store-csi-providers/: No such file or directory
```

## Root Cause
The CSI driver pod doesn't have the volume mount configured for the provider socket directory.

## Diagnostic Steps

### Step 1: Check CSI Driver Volume Mounts

```bash
# Get CSI driver pod name
kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}'

# Check volume mounts in the pod
kubectl describe pod -n kube-system -l app=secrets-store-csi-driver | findstr -A 10 "Mounts:"

# Check DaemonSet volume configuration
kubectl get daemonset secrets-store-csi-driver -n kube-system -o yaml | findstr -A 5 "volumeMounts"
kubectl get daemonset secrets-store-csi-driver -n kube-system -o yaml | findstr -A 5 "volumes:"
```

**Expected volume mount:**
```yaml
volumeMounts:
- name: providervol
  mountPath: /var/run/secrets-store-csi-providers
  
volumes:
- name: providervol
  hostPath:
    path: /var/run/secrets-store-csi-providers
    type: DirectoryOrCreate
```

### Step 2: Check AWS Provider Volume Mounts

```bash
# Check AWS provider volume mounts
kubectl describe pod -n kube-system -l app=csi-secrets-store-provider-aws | findstr -A 10 "Mounts:"

# Check DaemonSet volume configuration
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system -o yaml | findstr -A 5 "volumeMounts"
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system -o yaml | findstr -A 5 "volumes:"
```

### Step 3: Check if Directory Exists on Node

```bash
# Get node name
kubectl get nodes

# SSH to node (if you have access) or use a debug pod
kubectl debug node/<node-name> -it --image=busybox

# In the debug pod, check if directory exists
ls -la /host/var/run/secrets-store-csi-providers/
```

## Solution

The issue is likely that the Secrets Store CSI Driver chart doesn't have the provider volume mount configured. Let me check your CSI driver values file.

### Check Current CSI Driver Configuration

```bash
# List CSI driver Helm release
helm list -n kube-system | findstr secrets-store-csi-driver

# Get current values
helm get values secrets-store-csi-driver -n kube-system
```

### Fix: Update CSI Driver Values

The CSI driver needs to have provider volume mounts enabled. Check if you have a values file for the CSI driver.

**Location to check:**
- `charts/secrets-store-csi-driver/values-dev.yaml`
- `charts/secrets-store-csi-driver/values-prod.yaml`

**Required configuration:**
```yaml
# Enable provider volume mounts
linux:
  enabled: true
  kubeletRootDir: /var/lib/kubelet
  providersDir: /var/run/secrets-store-csi-providers
  
# Ensure volume mounts are configured
volumes:
  - name: providervol
    hostPath:
      path: /var/run/secrets-store-csi-providers
      type: DirectoryOrCreate

volumeMounts:
  - name: providervol
    mountPath: /var/run/secrets-store-csi-providers
```

### Quick Fix: Reinstall CSI Driver

If the CSI driver was installed without proper volume configuration:

```bash
# Uninstall current CSI driver
helm uninstall secrets-store-csi-driver -n kube-system

# Reinstall with correct configuration
helm upgrade --install secrets-store-csi-driver \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system --create-namespace \
  --set linux.enabled=true \
  --set linux.providersDir=/var/run/secrets-store-csi-providers
```

## Verification After Fix

```bash
# Wait for pods to restart
kubectl rollout status daemonset/secrets-store-csi-driver -n kube-system

# Check directory now exists
kubectl exec -n kube-system $(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/run/secrets-store-csi-providers/

# Should show aws.sock if AWS provider is running
```

