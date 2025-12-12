# Verify CSI Driver and AWS Provider Communication

This guide provides step-by-step verification to ensure the Secrets Store CSI Driver and AWS Provider are communicating correctly.

## Quick Verification (3 Steps)

```bash
# 1. Check both DaemonSets are running
kubectl get daemonset -n kube-system | findstr secrets-store

# 2. Check provider socket exists
kubectl exec -n kube-system -it $(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/run/secrets-store-csi-providers/

# 3. Create test SecretProviderClass and check for errors
kubectl apply -f - <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-communication
  namespace: default
spec:
  provider: aws
  parameters:
    region: us-east-1
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
EOF

kubectl describe secretproviderclass test-communication -n default
```

## Detailed Verification Steps

### Step 1: Verify Both Components Are Running

```bash
# Check CSI Driver DaemonSet
kubectl get daemonset secrets-store-csi-driver -n kube-system

# Expected output:
# NAME                       DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
# secrets-store-csi-driver   3         3         3       3            3

# Check AWS Provider DaemonSet
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system

# Expected output:
# NAME                              DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
# csi-secrets-store-provider-aws    3         3         3       3            3
```

**✅ Success Criteria:**
- Both DaemonSets show DESIRED = READY
- Number of pods matches number of nodes

**❌ If Failed:**
```bash
# Check pod status
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# Check pod logs for errors
kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=50
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50
```

### Step 2: Verify Provider Socket Registration

The CSI driver discovers providers through Unix socket files.

```bash
# Get CSI driver pod name
CSI_POD=$(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}')

# Check provider socket exists
kubectl exec -n kube-system $CSI_POD -- ls -la /var/run/secrets-store-csi-providers/
```

**✅ Expected Output:**
```
total 0
drwxr-xr-x    2 root     root            60 Dec 12 10:00 .
drwxr-xr-x    3 root     root            80 Dec 12 10:00 ..
srwxr-xr-x    1 root     root             0 Dec 12 10:00 aws.sock
```

**Key Points:**
- File `aws.sock` must exist
- File type should be `s` (socket)
- Permissions should be `rwxr-xr-x`

**❌ If Socket Missing:**
```bash
# Check AWS provider pods are running
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# Check AWS provider logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=100

# Check volume mounts
kubectl describe pod -n kube-system -l app=csi-secrets-store-provider-aws | findstr -A 5 "Mounts:"

# Restart AWS provider if needed
kubectl rollout restart daemonset/csi-secrets-store-provider-aws -n kube-system
```

### Step 3: Verify Provider Registration in CSI Driver Logs

The CSI driver logs should show the AWS provider is registered.

```bash
# Check CSI driver logs for provider registration
kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=100 | findstr -i "provider"
```

**✅ Expected Log Entries:**
```
I1212 10:00:00.123456       1 provider.go:123] "provider registered" provider="aws"
I1212 10:00:00.123456       1 provider.go:456] "provider client created" provider="aws"
```

**❌ If Provider Not Registered:**
```bash
# Check for errors in CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=200 | findstr -i "error\|failed\|warning"

# Check AWS provider logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=200 | findstr -i "error\|failed\|warning"
```

### Step 4: Test Provider Communication with SecretProviderClass

Create a test SecretProviderClass to verify the CSI driver can communicate with the AWS provider.

```bash
# Create test SecretProviderClass
kubectl apply -f - <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-aws-communication
  namespace: default
spec:
  provider: aws
  parameters:
    region: us-east-1
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
EOF

# Verify it was created
kubectl get secretproviderclass test-aws-communication -n default

# Check for any validation errors
kubectl describe secretproviderclass test-aws-communication -n default
```

**✅ Success Criteria:**
- SecretProviderClass is created without errors
- No events showing "provider not found"

**❌ Common Errors:**

**Error: "provider not found: provider aws"**
```
Events:
  Type     Reason              Age   From                     Message
  ----     ------              ----  ----                     -------
  Warning  ProviderNotFound    1s    secretproviderclass      provider not found: provider "aws"
```

**Solution:**
```bash
# Verify socket exists
kubectl exec -n kube-system $(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/run/secrets-store-csi-providers/

# Restart CSI driver to re-discover providers
kubectl rollout restart daemonset/secrets-store-csi-driver -n kube-system

# Wait for rollout
kubectl rollout status daemonset/secrets-store-csi-driver -n kube-system
```

### Step 5: Test End-to-End with a Pod (Optional)

**Note:** This requires an actual secret in AWS Secrets Manager.

```bash
# Create a test secret in AWS (if you have one)
# aws secretsmanager create-secret --name test-secret --secret-string '{"key":"value"}' --region us-east-1

# Create test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-secrets-mount
  namespace: default
spec:
  serviceAccountName: default
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
        secretProviderClass: "test-aws-communication"
EOF

# Wait for pod to start
kubectl wait --for=condition=Ready pod/test-secrets-mount --timeout=60s

# Check pod status
kubectl get pod test-secrets-mount

# Check pod events
kubectl describe pod test-secrets-mount
```

**✅ Success Criteria:**
- Pod reaches Running state
- No errors in pod events
- Volume is mounted successfully

**❌ Common Errors:**

**Error: "failed to mount secrets store objects"**
```
Events:
  Warning  FailedMount  1s  kubelet  MountVolume.SetUp failed for volume "secrets-store" : 
           rpc error: code = Unknown desc = failed to mount secrets store objects for pod default/test-secrets-mount, 
           err: rpc error: code = Unknown desc = provider not found: provider "aws"
```

**Solution:** Provider socket not found - see Step 2

**Error: "AccessDeniedException"**
```
Events:
  Warning  FailedMount  1s  kubelet  MountVolume.SetUp failed for volume "secrets-store" : 
           rpc error: code = Unknown desc = failed to mount secrets store objects for pod default/test-secrets-mount, 
           err: rpc error: code = Unknown desc = AccessDeniedException: User is not authorized
```

**Solution:** IAM permissions issue - not a communication problem

**Cleanup:**
```bash
kubectl delete pod test-secrets-mount
kubectl delete secretproviderclass test-aws-communication
```

### Step 6: Verify Volume Mount Configuration

Both DaemonSets must mount the same host path for socket communication.

```bash
# Check CSI driver volume mounts
kubectl get daemonset secrets-store-csi-driver -n kube-system -o yaml | findstr -A 5 "hostPath"

# Check AWS provider volume mounts
kubectl get daemonset csi-secrets-store-provider-aws -n kube-system -o yaml | findstr -A 5 "hostPath"
```

**✅ Expected Configuration:**

Both should have:
```yaml
hostPath:
  path: /var/run/secrets-store-csi-providers
  type: DirectoryOrCreate
```

### Step 7: Check Provider Health via Logs

```bash
# Check AWS provider startup logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50 | findstr -i "starting\|ready\|listening"

# Check for gRPC server status
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50 | findstr -i "grpc\|server"
```

**✅ Expected Log Entries:**
```
I1212 10:00:00.123456       1 main.go:123] "starting provider" version="2.1.0"
I1212 10:00:00.123456       1 server.go:456] "gRPC server listening" address="unix:///var/run/secrets-store-csi-providers/aws.sock"
```

## Verification Checklist

Use this checklist to confirm communication is working:

- [ ] **Both DaemonSets running**: CSI driver and AWS provider pods are all Ready
- [ ] **Socket file exists**: `aws.sock` present in `/var/run/secrets-store-csi-providers/`
- [ ] **Provider registered**: CSI driver logs show AWS provider registration
- [ ] **SecretProviderClass created**: No "provider not found" errors
- [ ] **Volume mounts correct**: Both DaemonSets mount same host path
- [ ] **No errors in logs**: Both components show healthy startup logs

## Automated Verification Script

Save as `verify-communication.ps1`:

```powershell
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CSI Driver <-> AWS Provider Communication Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check DaemonSets
Write-Host "[1/5] Checking DaemonSets..." -ForegroundColor Yellow
$csiDs = kubectl get daemonset secrets-store-csi-driver -n kube-system --no-headers 2>$null
$awsDs = kubectl get daemonset csi-secrets-store-provider-aws -n kube-system --no-headers 2>$null

if ($csiDs -and $awsDs) {
    Write-Host "  ✓ Both DaemonSets found" -ForegroundColor Green
    kubectl get daemonset -n kube-system | Select-String "secrets-store"
} else {
    Write-Host "  ✗ DaemonSets missing!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Check provider socket
Write-Host "[2/5] Checking provider socket..." -ForegroundColor Yellow
$csiPod = kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}' 2>$null

if ($csiPod) {
    $socket = kubectl exec -n kube-system $csiPod -- ls /var/run/secrets-store-csi-providers/ 2>$null | Select-String "aws.sock"
    if ($socket) {
        Write-Host "  ✓ AWS provider socket found" -ForegroundColor Green
        kubectl exec -n kube-system $csiPod -- ls -la /var/run/secrets-store-csi-providers/
    } else {
        Write-Host "  ✗ AWS provider socket NOT found!" -ForegroundColor Red
        Write-Host "  Available sockets:" -ForegroundColor Yellow
        kubectl exec -n kube-system $csiPod -- ls -la /var/run/secrets-store-csi-providers/
    }
} else {
    Write-Host "  ✗ CSI driver pod not found!" -ForegroundColor Red
}
Write-Host ""

# Step 3: Check CSI driver logs for provider registration
Write-Host "[3/5] Checking provider registration..." -ForegroundColor Yellow
$providerLogs = kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=100 2>$null | Select-String -Pattern "provider.*aws" -CaseSensitive:$false

if ($providerLogs) {
    Write-Host "  ✓ Provider registration found in logs" -ForegroundColor Green
    $providerLogs | Select-Object -First 3
} else {
    Write-Host "  ⚠ No provider registration found in logs" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Test SecretProviderClass creation
Write-Host "[4/5] Testing SecretProviderClass creation..." -ForegroundColor Yellow
$testSpc = @"
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-communication-verify
  namespace: default
spec:
  provider: aws
  parameters:
    region: us-east-1
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
"@

$testSpc | kubectl apply -f - 2>&1 | Out-Null
Start-Sleep -Seconds 2

$spcStatus = kubectl get secretproviderclass test-communication-verify -n default 2>$null
if ($spcStatus) {
    Write-Host "  ✓ SecretProviderClass created successfully" -ForegroundColor Green
    
    # Check for errors
    $spcEvents = kubectl describe secretproviderclass test-communication-verify -n default 2>$null | Select-String "provider not found"
    if ($spcEvents) {
        Write-Host "  ✗ Provider not found error detected!" -ForegroundColor Red
    } else {
        Write-Host "  ✓ No provider errors detected" -ForegroundColor Green
    }
    
    # Cleanup
    kubectl delete secretproviderclass test-communication-verify -n default 2>&1 | Out-Null
} else {
    Write-Host "  ✗ Failed to create SecretProviderClass" -ForegroundColor Red
}
Write-Host ""

# Step 5: Check for errors in logs
Write-Host "[5/5] Checking for errors in logs..." -ForegroundColor Yellow
$csiErrors = kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=50 2>$null | Select-String -Pattern "error|failed" -CaseSensitive:$false
$awsErrors = kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50 2>$null | Select-String -Pattern "error|failed" -CaseSensitive:$false

if (-not $csiErrors -and -not $awsErrors) {
    Write-Host "  ✓ No errors found in logs" -ForegroundColor Green
} else {
    if ($csiErrors) {
        Write-Host "  ⚠ Errors found in CSI driver logs:" -ForegroundColor Yellow
        $csiErrors | Select-Object -First 3
    }
    if ($awsErrors) {
        Write-Host "  ⚠ Errors found in AWS provider logs:" -ForegroundColor Yellow
        $awsErrors | Select-Object -First 3
    }
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
```

## Summary

**Communication is working if:**
1. ✅ Both DaemonSets are running with all pods Ready
2. ✅ Socket file `aws.sock` exists in CSI driver pods
3. ✅ SecretProviderClass can be created without "provider not found" errors
4. ✅ No errors in logs from either component

**Communication is NOT working if:**
1. ❌ "provider not found: provider aws" error appears
2. ❌ Socket file `aws.sock` is missing
3. ❌ Pods fail to mount secrets with provider-related errors

The key indicator is the presence of the `aws.sock` file - if it exists and the CSI driver can access it, communication is working correctly.

