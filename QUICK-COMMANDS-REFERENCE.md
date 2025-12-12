# AWS Secrets Manager Provider - Quick Commands Reference

## Verified Working Commands

These commands have been tested and confirmed working with the deployed AWS Secrets Manager Provider.

### Check Deployment Status

```bash
# Check DaemonSet
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system

# Check all secrets-store related DaemonSets
kubectl get daemonset -n kube-system | findstr secrets-store
```

### Check Pods

```bash
# Get AWS Provider pods (VERIFIED WORKING)
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# Get all secrets-store pods
kubectl get pods -n kube-system | findstr secrets-store

# Watch pods status
kubectl get pods -n kube-system -l app=secrets-store-csi-driver-provider-aws -w
```

### Check Logs

```bash
# View AWS Provider logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver-provider-aws --tail=50

# Follow logs in real-time
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws -f

# Get logs from specific pod
kubectl logs -n kube-system <pod-name> --tail=100
```

### Check Service Account

```bash
# Get service account details
kubectl get sa csi-secrets-store-provider-aws -n kube-system -o yaml

# Check IAM role annotations
kubectl get sa csi-secrets-store-provider-aws -n kube-system -o yaml | findstr eks.amazonaws.com

# Expected annotations:
# eks.amazonaws.com/role-arn
# eks.amazonaws.com/pod-identity-association-role-arn
```

### Verify Provider Registration

```bash
# Get CSI driver pod name
kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath="{.items[0].metadata.name}"

# Check provider socket (replace <csi-driver-pod> with actual pod name)
kubectl exec -n kube-system <csi-driver-pod> -- ls -la /var/run/secrets-store-csi-providers/

# Should show: aws.sock
```

### Test IAM Role

```bash
# Get AWS Provider pod name
kubectl get pod -n kube-system -l app=csi-secrets-store-provider-aws -o jsonpath="{.items[0].metadata.name}"

# Test IAM role assumption (replace <provider-pod> with actual pod name)
kubectl exec -n kube-system <provider-pod> -- aws sts get-caller-identity

# Should show: EKS-SecretsStore-Role-{env}
```

### Check SecretProviderClass

```bash
# List all SecretProviderClasses
kubectl get secretproviderclass -A

# Get specific SecretProviderClass
kubectl get secretproviderclass <name> -n <namespace> -o yaml

# Describe SecretProviderClass
kubectl describe secretproviderclass <name> -n <namespace>
```

### Check Secrets

```bash
# List secrets in namespace
kubectl get secrets -n <namespace>

# Get specific secret
kubectl get secret <secret-name> -n <namespace> -o yaml

# Decode secret value
kubectl get secret <secret-name> -n <namespace> -o jsonpath="{.data.<key>}" | base64 -d
```

### Troubleshooting Commands

```bash
# Describe DaemonSet
kubectl describe daemonset csi-secrets-store-provider-aws -n kube-system

# Describe pod
kubectl describe pod -n kube-system -l app=csi-secrets-store-provider-aws

# Check events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | findstr secrets-store

# Restart DaemonSet (if needed)
kubectl rollout restart daemonset/csi-secrets-store-provider-aws -n kube-system

# Check rollout status
kubectl rollout status daemonset/csi-secrets-store-provider-aws -n kube-system
```

### Helm Commands

```bash
# List Helm releases
helm list -n kube-system

# Get Helm release values
helm get values secrets-store-csi-driver-provider-aws -n kube-system

# Get Helm release manifest
helm get manifest secrets-store-csi-driver-provider-aws -n kube-system

# Helm upgrade (dev)
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n kube-system --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml

# Helm upgrade (prod)
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n kube-system --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml

# Helm uninstall (if needed)
helm uninstall secrets-store-csi-driver-provider-aws -n kube-system
```

### One-Liner Status Check

```bash
# Complete status check
echo "=== DaemonSet ===" & kubectl get daemonset csi-secrets-store-provider-aws -n kube-system & echo. & echo "=== Pods ===" & kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws & echo. & echo "=== Service Account ===" & kubectl get sa csi-secrets-store-provider-aws -n kube-system
```

### PowerShell One-Liner

```powershell
# Complete status check (PowerShell)
Write-Host "=== DaemonSet ===" -ForegroundColor Cyan; kubectl get daemonset csi-secrets-store-provider-aws -n kube-system; Write-Host "`n=== Pods ===" -ForegroundColor Cyan; kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws; Write-Host "`n=== Service Account ===" -ForegroundColor Cyan; kubectl get sa csi-secrets-store-provider-aws -n kube-system
```

## Important Labels

The AWS Secrets Manager Provider uses these labels:

- **app**: `csi-secrets-store-provider-aws` ✅ (VERIFIED WORKING)
- **app.kubernetes.io/name**: `csi-secrets-store-provider-aws`
- **app.kubernetes.io/instance**: `<release-name>`

## Common Selectors

```bash
# By app label (RECOMMENDED)
-l app=csi-secrets-store-provider-aws

# By app.kubernetes.io/name label
-l app.kubernetes.io/name=csi-secrets-store-provider-aws

# By multiple labels
-l app=csi-secrets-store-provider-aws,app.kubernetes.io/instance=csi-secrets-store-provider-aws
```

## Environment Variables

Set these for easier command execution:

```bash
# Set namespace
set NAMESPACE=kube-system

# Set app label
set APP_LABEL=app=secrets-store-csi-driver-provider-aws

# Use in commands
kubectl get pods -n %NAMESPACE% -l %APP_LABEL%
```

### PowerShell Version

```powershell
# Set namespace
$NAMESPACE = "kube-system"

# Set app label
$APP_LABEL = "app=secrets-store-csi-driver-provider-aws"

# Use in commands
kubectl get pods -n $NAMESPACE -l $APP_LABEL
```

## Quick Verification Script

Save this as `verify-aws-provider.cmd`:

```batch
@echo off
echo ========================================
echo AWS Secrets Manager Provider Status
echo ========================================
echo.

echo [1/5] Checking DaemonSet...
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system
echo.

echo [2/5] Checking Pods...
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws
echo.

echo [3/5] Checking Service Account...
kubectl get sa csi-secrets-store-provider-aws -n kube-system
echo.

echo [4/5] Checking IAM Role Annotations...
kubectl get sa csi-secrets-store-provider-aws -n kube-system -o yaml | findstr eks.amazonaws.com
echo.

echo [5/5] Checking Recent Logs...
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=10
echo.

echo ========================================
echo Verification Complete
echo ========================================
```

### PowerShell Version

Save this as `verify-aws-provider.ps1`:

```powershell
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AWS Secrets Manager Provider Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Checking DaemonSet..." -ForegroundColor Yellow
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system
Write-Host ""

Write-Host "[2/5] Checking Pods..." -ForegroundColor Yellow
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws
Write-Host ""

Write-Host "[3/5] Checking Service Account..." -ForegroundColor Yellow
kubectl get sa csi-secrets-store-provider-aws -n kube-system
Write-Host ""

Write-Host "[4/5] Checking IAM Role Annotations..." -ForegroundColor Yellow
kubectl get sa csi-secrets-store-provider-aws -n kube-system -o yaml | Select-String "eks.amazonaws.com"
Write-Host ""

Write-Host "[5/5] Checking Recent Logs..." -ForegroundColor Yellow
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=10
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
```

## Notes

- All commands use the **kube-system** namespace (not secrets-store-csi-driver)
- The correct label selector is `app=csi-secrets-store-provider-aws`
- DaemonSet name is `csi-secrets-store-provider-aws`
- Service account name is `csi-secrets-store-provider-aws`
- IAM role pattern is `EKS-SecretsStore-Role-{environment}`

